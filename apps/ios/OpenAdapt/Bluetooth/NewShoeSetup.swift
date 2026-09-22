import Foundation
import Combine

/// One physical confirmation at a time. The second shoe never starts enrollment
/// until the first shoe's candidate key has authenticated and been saved.
@MainActor
final class NewShoeSetup: ObservableObject {
    enum Phase: Equatable { case idle, searching, connecting, confirm, saving, complete, failed }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var firstPairedSide: ShoeSide?
    @Published private(set) var running = false
    @Published private(set) var error: String?
    var complete: Bool { phase == .complete }
    var nextSide: ShoeSide? { firstPairedSide.map { $0 == .left ? .right : .left } }
    private var task: Task<Void, Never>?
    private let vault = EnrollmentVault()
    private var previewing: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ui-onboarding")
        #else
        return false
        #endif
    }

    func start(bluetooth: BluetoothController, store: AppStore, afterReset: Bool = false) {
        guard !running else { return }
        error = nil; firstPairedSide = nil; running = true; phase = .searching
        store.beginNewShoeSetup()
        task = Task {
            defer { running = false; task = nil }
            do {
                let nearby = try await bluetooth.discoverNewShoes()
                let candidates = try candidates(in: nearby)
                let retained = previewing || afterReset ? [] : try vault.load()
                // Resume the saved first foot before moving on to its partner.
                // RSSI only chooses which shoe to approach first; it never sets side.
                let first = candidates.sorted { a, b in
                    func saved(_ shoe: NearbyShoe) -> Bool {
                        retained.contains { $0.identity == shoe.advertisement?.identity && $0.candidateKey != nil && $0.supersededAfterReset != true }
                    }
                    if saved(a) != saved(b) { return saved(a) }
                    return a.rssi > b.rssi
                }[0]
                let firstRecord = try await pair(first, bluetooth: bluetooth, afterReset: afterReset)
                try Task.checkCancellation()
                firstPairedSide = firstRecord.side
                let opposite: ShoeSide = firstRecord.side == .left ? .right : .left
                // The partner can be awake already or appear after the first step.
                let second: NearbyShoe
                if let found = candidates.first(where: { $0.advertisement?.side == opposite }) { second = found }
                else {
                    phase = .searching
                    let found = try await bluetooth.discoverNewShoes()
                    let partners = try self.candidates(in: found, side: opposite)
                    second = partners[0]
                }
                let secondRecord = try await pair(second, bluetooth: bluetooth, afterReset: afterReset)
                try Task.checkCancellation()
                phase = .saving
                try store.saveEnrolledShoes([firstRecord, secondRecord])
                phase = .complete
            } catch is CancellationError { return }
            catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                phase = .failed
            }
        }
    }
    func cancel() { task?.cancel() }

    private func candidates(in shoes: [NearbyShoe], side: ShoeSide? = nil) throws -> [NearbyShoe] {
        let supported = shoes.filter { $0.model == .adaptAutoMax && $0.advertisement != nil && (side == nil || $0.advertisement?.side == side) }
        guard !supported.isEmpty else {
            throw SetupProblem(side.map { "Wake your \($0.title.lowercased()) shoe and keep it near your iPhone, then try again." }
                ?? (shoes.isEmpty ? "Wake a shoe and keep it near your iPhone, then try again." : "We couldn’t identify a supported Auto Max shoe. Keep your shoes nearby and try again."))
        }
        guard supported.count <= 2, Set(supported.compactMap { $0.advertisement?.side }).count == supported.count else {
            throw SetupProblem("Keep only the pair you want to add awake and nearby, then try again.")
        }
        return supported
    }
    private struct SetupProblem: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    private func pair(_ shoe: NearbyShoe, bluetooth: BluetoothController, afterReset: Bool) async throws -> ShoeEnrollmentRecord {
        phase = .connecting
        #if DEBUG
        if previewing { return try await previewPair(shoe) }
        #endif
        defer { bluetooth.disconnect(id: shoe.id) }
        try Task.checkCancellation()
        guard let advertisement = shoe.advertisement else { throw ShoeEnrollmentError.identity }
        if afterReset {
            // Explicit acknowledgement of a manual reset. Preserve old recovery keys.
            for var record in try vault.load() where record.identity == advertisement.identity && record.supersededAfterReset != true {
                record.supersededAfterReset = true
                try vault.save(record)
            }
        }
        let matching = try vault.load().filter { $0.identity == advertisement.identity && $0.supersededAfterReset != true }
        guard matching.count <= 1 else { throw ShoeEnrollmentError.storage }
        var record = matching.first ?? ShoeEnrollmentRecord(peripheralID: shoe.id, advertisedName: shoe.name, advertisement: advertisement)
        guard record.side == advertisement.side, record.advertisedName == shoe.name else { throw ShoeEnrollmentError.identity }
        record.peripheralID = shoe.id
        // Opening the link checks firmware before any Nike protocol command.
        let link = try await bluetooth.connect(id: shoe.id, expectedName: shoe.name)
        guard let session = link.session else { throw AdaptError.disconnected }
        return try await ShoeEnrollment.run(session: session, record: record,
            save: { try self.vault.save($0) }, onReady: { self.phase = .confirm })
    }

    #if DEBUG
    /// Synthetic shoe responses share the real sequential coordinator above.
    /// They cannot reach Bluetooth or Keychain and are ignored by Release builds.
    private func previewPair(_ shoe: NearbyShoe) async throws -> ShoeEnrollmentRecord {
        try await Task.sleep(for: .milliseconds(300))
        phase = .confirm
        let args = ProcessInfo.processInfo.arguments
        let advance = args.contains("--ui-enrollment-complete") ||
            (firstPairedSide == nil && args.contains("--ui-enrollment-second"))
        if args.contains("--ui-enrollment-fail-first") { throw ShoeEnrollmentError.notReady }
        try await Task.sleep(for: advance ? .milliseconds(900) : .seconds(90))
        try Task.checkCancellation()
        var record = ShoeEnrollmentRecord(peripheralID: shoe.id, advertisedName: shoe.name, advertisement: shoe.advertisement!)
        let group = record.side == .left ? 1 : 2
        let exchange = try ShoeEnrollmentExchange(group: group, restoring: Data([3]))
        record.group = group; record.privateKey = try exchange.recoveryKey(); record.publicKey = try exchange.publicKey()
        record.peerPublicKey = Data([32]); record.candidateKey = try exchange.derive(peerPublicKey: Data([32]))
        record.phase = .verified
        return record
    }
    #endif
}
