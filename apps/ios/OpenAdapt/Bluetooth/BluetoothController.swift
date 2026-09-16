import Foundation
import CoreBluetooth
import Combine

private enum GATT {
    static let service = CBUUID(string: "1a2328af-3d0b-4b04-a2aa-973c239d3904")
    static let write = CBUUID(string: "226baea6-1543-40c2-8eae-a69b02171b08")
    static let notify = CBUUID(string: "30c4142f-b083-42cf-865a-d5b91801bcd7")
    static let information = CBUUID(string: "180A")
    static let firmware = CBUUID(string: "2A26")
}

struct NearbyShoe: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    var proximity: String { rssi > -55 ? "Very close" : rssi > -75 ? "Nearby" : "Farther away" }
}

/// Delegate isolation is checked at runtime; the central is explicitly on .main.
/// CoreBluetooth owns system pairing. No Linux address is treated as an iOS UUID.
@MainActor
final class BluetoothController: NSObject, ObservableObject, @preconcurrency CBCentralManagerDelegate {
    @Published var nearby: [NearbyShoe] = []
    @Published var scanning = false
    @Published var availability = "Ready to scan"
    private var central: CBCentralManager?
    private var peripherals = [UUID: CBPeripheral]()
    private var links = [UUID: PeripheralLink]()
    private var scanTask: Task<Void, Never>?
    private var scanRequested = false
    private var discoveryRequests = Set<UUID>()

    func scan() {
        scanRequested = true
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else if central?.state == .poweredOn { startScan() }
        else { availability = "Enable Bluetooth and allow OpenAdapt access in Settings." }
    }
    private func startScan() {
        stopScan(); scanRequested = false; nearby = []; scanning = true
        availability = "Looking for awake Auto Max shoes…"
        central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.stopScan()
            self?.availability = self?.nearby.isEmpty == true ? "No shoes found. Wake your shoes and scan again." : "Choose a shoe to connect."
        }
    }
    func stopScan() { central?.stopScan(); scanning = false; scanRequested = false; scanTask?.cancel() }
    func connect(id: UUID, expectedName: String) async throws -> PeripheralLink {
        guard central?.state == .poweredOn else { throw AdaptError.unavailable }
        try await waitForClosingConnection(id)
        guard let peripheral = peripherals[id],
              nearby.contains(where: { $0.id == id && $0.name == expectedName }) else { throw AdaptError.invalidProfile }
        if discoveryRequests.isEmpty { stopScan() }
        return try await open(peripheral)
    }
    func connectSaved(id: UUID?, expectedName: String, allowsNameMatch: Bool) async throws -> PeripheralLink {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-bluetooth-off") {
            throw ShoeConnectionError.bluetooth("Turn on Bluetooth to connect your shoes.")
        }
        #endif
        return try await SavedShoeConnection.connect(rememberedID: id, expectedName: expectedName,
            retrieve: { try await self.connectRemembered(id: $0, expectedName: expectedName, timeout: 8) },
            discover: { try await self.discoverSavedShoe(named: $0, rememberedID: id, allowsNameMatch: allowsNameMatch) },
            connectDiscovered: { try await self.connect(id: $0, expectedName: expectedName) },
            discard: { self.disconnect(id: $0.peripheral.identifier) })
    }

    private func discoverSavedShoe(named expectedName: String, rememberedID: UUID?, allowsNameMatch: Bool) async throws -> UUID {
        if rememberedID == nil && !allowsNameMatch { throw ShoeConnectionError.ambiguousShoes }
        try await prepareCentral()
        let request = UUID()
        if discoveryRequests.isEmpty { stopScan(); nearby = [] }
        discoveryRequests.insert(request)
        defer {
            discoveryRequests.remove(request)
            if discoveryRequests.isEmpty { stopScan() }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while true {
            try Task.checkCancellation()
            guard central?.state == .poweredOn else { throw ShoeConnectionError.bluetooth(availability) }
            let candidates = Dictionary(uniqueKeysWithValues: nearby.map { ($0.id, $0.name) })
            if let id = try SavedShoeConnection.discoveryCandidate(in: candidates, expectedName: expectedName,
                rememberedID: rememberedID, allowsNameMatch: allowsNameMatch) { return id }
            guard ContinuousClock.now < deadline else { throw ShoeConnectionError.notFound }
            // Discovery is shared by both feet. Connecting one must not end
            // the other foot's search, and UI scan cancellation can be resumed.
            if central?.isScanning != true {
                scanning = true; availability = "Looking for your saved shoes…"
                central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    /// Only called with a UUID saved AFTER successful shoe authentication.
    /// Cached CoreBluetooth identifiers work without a background discovery scan.
    func connectRemembered(id: UUID, expectedName: String, timeout: TimeInterval = 35) async throws -> PeripheralLink {
        try await prepareCentral()
        try await waitForClosingConnection(id)
        guard let peripheral = central?.retrievePeripherals(withIdentifiers: [id]).first else {
            throw ShoeConnectionError.rediscoveryRequired
        }
        // CoreBluetooth's cached display name can differ from the advertisement.
        // This UUID was authenticated already; its saved key is checked again by
        // AppStore. Never substitute a different shoe based on a shared name.
        return try await open(peripheral, timeout: timeout)
    }
    private func prepareCentral() async throws {
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while central?.state == .unknown || central?.state == .resetting {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else {
                throw ShoeConnectionError.bluetooth("Bluetooth is still starting. Try connecting again.")
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
        guard central?.state == .poweredOn else {
            throw ShoeConnectionError.bluetooth(availability)
        }
    }
    private func waitForClosingConnection(_ id: UUID) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        // A preceding one-shot intent may still be receiving didDisconnect.
        while let previous = links[id], previous.closed {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw AdaptError.timeout }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard links[id] == nil else {
            throw ShoeConnectionError.bluetooth("This shoe is already connecting. Wait a moment and try again.")
        }
    }
    private func open(_ peripheral: CBPeripheral, timeout: TimeInterval = 35) async throws -> PeripheralLink {
        try Task.checkCancellation()
        guard central?.state == .poweredOn else { throw ShoeConnectionError.bluetooth(availability) }
        let id = peripheral.identifier
        let link = PeripheralLink(peripheral: peripheral)
        links[id] = link
        link.cancelConnection = { [weak self, weak peripheral] in
            guard let peripheral else { return }
            self?.central?.cancelPeripheralConnection(peripheral)
        }
        do {
            try await link.open(timeout: timeout) { self.central?.connect(peripheral) }
            return link
        } catch { disconnect(id: id); throw error }
    }
    func disconnect(id: UUID) {
        guard let link = links[id] else { return }
        link.close(AdaptError.disconnected)
        central?.cancelPeripheralConnection(link.peripheral)
        // Keep the entry until CoreBluetooth confirms disconnect; stale callbacks
        // must never close a newly connected session for the same peripheral.
    }
    func disconnectAll() { stopScan(); for id in Array(links.keys) { disconnect(id: id) } }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            availability = "Ready to scan"
            if scanRequested { startScan() }
        case .unauthorized: availability = "Allow Bluetooth access in iPhone Settings."
        case .poweredOff: availability = "Turn on Bluetooth to connect your shoes."
        case .unsupported: availability = "Bluetooth is unavailable on this device."
        default: availability = "Bluetooth is getting ready…"
        }
        if central.state != .poweredOn {
            let pending = scanRequested
            stopScan()
            if central.state == .unknown || central.state == .resetting { scanRequested = pending }
            for link in links.values { link.close(AdaptError.unavailable) }
            links.removeAll()
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard scanning, let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name,
              name.range(of: "^004-[A-Z0-9]+-[0-9]{3}$", options: .regularExpression) != nil else { return }
        peripherals[peripheral.identifier] = peripheral
        if !nearby.contains(where: { $0.id == peripheral.identifier }) {
            nearby.append(NearbyShoe(id: peripheral.identifier, name: name, rssi: RSSI.intValue))
            nearby.sort { $0.rssi > $1.rssi }
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let link = links[peripheral.identifier], !link.closed else {
            central.cancelPeripheralConnection(peripheral); return
        }
        peripheral.discoverServices([GATT.service, GATT.information])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        links.removeValue(forKey: peripheral.identifier)?.close(AdaptError.disconnected)
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        links.removeValue(forKey: peripheral.identifier)?.close(AdaptError.disconnected)
    }
}

@MainActor
final class PeripheralLink: NSObject, @preconcurrency CBPeripheralDelegate {
    let peripheral: CBPeripheral
    private(set) var session: ShoeSession?
    private(set) var closed = false
    var onDisconnect: (() -> Void)?
    var onPosition: ((Int) -> Void)?
    var cancelConnection: (() -> Void)?
    private var writer: CBCharacteristic?
    private var notifier: CBCharacteristic?
    private var revision: CBCharacteristic?
    private var discovered = Set<CBUUID>()
    private var ready: CheckedContinuation<Void, Error>?
    private var outbound: [(Data, CheckedContinuation<Void, Error>)] = []
    private var timeoutTask: Task<Void, Never>?
    private var writeTimer: Task<Void, Never>?

    init(peripheral: CBPeripheral) { self.peripheral = peripheral; super.init(); peripheral.delegate = self }
    func open(timeout: TimeInterval = 35, start: () -> Void) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                ready = continuation
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(timeout))
                    guard !Task.isCancelled else { return }
                    self?.close(AdaptError.timeout); self?.cancelConnection?()
                }
                start()
            }
        } onCancel: { Task { @MainActor [weak self] in self?.close(CancellationError()); self?.cancelConnection?() } }
    }
    func close(_ error: Error) {
        guard !closed else { return }
        closed = true; timeoutTask?.cancel(); writeTimer?.cancel()
        session?.channel.close(error)
        let pendingReady = ready; ready = nil; pendingReady?.resume(throwing: error)
        let pendingWrites = outbound; outbound.removeAll()
        for (_, continuation) in pendingWrites { continuation.resume(throwing: error) }
        onDisconnect?()
    }
    private func fail(_ error: Error) { close(error); cancelConnection?() }
    private func write(_ packet: Data) async throws {
        guard !closed, peripheral.state == .connected, writer != nil else { throw AdaptError.disconnected }
        guard outbound.count < 32 else { throw AdaptError.busy }
        try await withCheckedThrowingContinuation { continuation in
            outbound.append((packet, continuation))
            flushWrites()
        }
    }
    // Data fragments and flow acknowledgements share one ordered writer. A
    // notification may arrive while CoreBluetooth is applying backpressure.
    private func flushWrites() {
        guard !closed, peripheral.state == .connected, let writer else { return }
        while peripheral.canSendWriteWithoutResponse, !outbound.isEmpty {
            let (packet, continuation) = outbound.removeFirst()
            peripheral.writeValue(packet, for: writer, type: .withoutResponse)
            continuation.resume()
        }
        if outbound.isEmpty { writeTimer?.cancel(); writeTimer = nil }
        else if writeTimer == nil {
            writeTimer = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.fail(AdaptError.timeout)
            }
        }
    }
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) { flushWrites() }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard !closed else { return }
        guard error == nil, let services = peripheral.services,
              services.filter({ $0.uuid == GATT.service }).count == 1,
              services.filter({ $0.uuid == GATT.information }).count == 1 else { fail(AdaptError.unsupportedFirmware); return }
        for service in services {
            if service.uuid == GATT.service { peripheral.discoverCharacteristics([GATT.write, GATT.notify], for: service) }
            if service.uuid == GATT.information { peripheral.discoverCharacteristics([GATT.firmware], for: service) }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard !closed else { return }
        guard error == nil, let chars = service.characteristics else { fail(AdaptError.malformedMessage); return }
        if service.uuid == GATT.service {
            let writers = chars.filter { $0.uuid == GATT.write && $0.properties.contains(.writeWithoutResponse) }
            let notifiers = chars.filter { $0.uuid == GATT.notify && $0.properties.contains(.notify) }
            guard writers.count == 1, notifiers.count == 1 else { fail(AdaptError.malformedMessage); return }
            writer = writers[0]; notifier = notifiers[0]
        } else if service.uuid == GATT.information {
            let revisions = chars.filter { $0.uuid == GATT.firmware && $0.properties.contains(.read) }
            guard revisions.count == 1 else { fail(AdaptError.unsupportedFirmware); return }
            revision = revisions[0]
        }
        discovered.insert(service.uuid)
        if discovered.contains(GATT.service), discovered.contains(GATT.information), let revision {
            peripheral.readValue(for: revision)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard !closed else { return }
        guard error == nil, let value = characteristic.value else { fail(AdaptError.disconnected); return }
        if characteristic.uuid == GATT.firmware {
            do {
                try ShoeCrypto.verifyFirmware(value)
                guard let notifier else { throw AdaptError.malformedMessage }
                peripheral.setNotifyValue(true, for: notifier)
            } catch { fail(error) }
        } else if characteristic.uuid == GATT.notify { session?.channel.receive(value) }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard !closed, characteristic.uuid == GATT.notify else { return }
        guard error == nil, characteristic.isNotifying, session == nil else { fail(AdaptError.disconnected); return }
        let channel = ShoeChannel { [weak self] packet in
            guard let self else { throw AdaptError.disconnected }
            try await self.write(packet)
        }
        channel.onIdlePosition = { [weak self] position in self?.onPosition?(position) }
        channel.onFailure = { [weak self] error in
            guard let self, self.session?.isExecuting != true else { return }
            self.fail(error)
        }
        session = ShoeSession(channel: channel)
        timeoutTask?.cancel(); let pending = ready; ready = nil; pending?.resume()
    }
}
