#if DEBUG
import SwiftUI
import UniformTypeIdentifiers

private struct PairingDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw AdaptError.invalidProfile }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct PairingExportSection: View {
    @EnvironmentObject private var store: AppStore
    @State private var document: PairingDocument?
    @State private var exporting = false
    @State private var failed = false

    var body: some View {
        Section {
            if let pair = store.pair, !store.demo {
                LabeledContent("Selected pair", value: pair.displayName)
                Button {
                    do {
                        document = try PairingDocument(data: PairingExport.encode(pair))
                        exporting = true
                    } catch { failed = true }
                } label: {
                    Label("Export pairing file", systemImage: "square.and.arrow.up")
                }.accessibilityIdentifier("export-pairing")
            } else {
                Text("Pair your shoes first to export their connection details.")
            }
        } header: {
            Text("Use on Omarchy")
        } footer: {
            Text("Save this file, then import it in Omarchy’s New shoes page. It contains private pairing keys—share it only with your own devices. Bluetooth pairing may still be needed on Omarchy.")
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: "OpenAdapt-pairing.private") { result in
            document = nil
            if case .failure = result { failed = true }
        }
        .alert("Couldn’t export pairing", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your saved pairing is unchanged. Try exporting again.")
        }
    }
}
#endif
