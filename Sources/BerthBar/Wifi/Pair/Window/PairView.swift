import BerthCore
import SwiftUI

struct PairView: View {
    @Bindable var flow: PairFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch flow.state {
            case let .waitingForQR(qr):
                qrStep(qr)
            case .notFound:
                notFoundStep
            case let .codeEntry(error):
                codeStep(error: error)
            case .pairing:
                progress("Pairing…")
            case .connecting:
                progress("Connecting…")
            case let .manualConnect(error):
                manualStep(error: error)
            case let .connected(device):
                Label(PairCopy.connected(device), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
        }
        .padding(20)
        .frame(width: 400, alignment: .leading)
    }

    private func qrStep(_ qr: PairQR) -> some View {
        VStack(alignment: .center, spacing: 12) {
            if let image = PairQRImage.make(payload: qr.payload) {
                Image(decorative: image, scale: 2)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
            }
            Text(PairCopy.qrSteps).multilineTextAlignment(.center)
            Text("Scan this code.").foregroundStyle(.secondary)
            Button("Use pairing code instead") { flow.usePairingCode() }
        }
        .frame(maxWidth: .infinity)
    }

    private var notFoundStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PairCopy.notFound)
            HStack {
                Button("Retry") { flow.retry() }
                Button("Use pairing code instead") { flow.usePairingCode() }
            }
        }
    }

    private func codeStep(error: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On the phone: Wireless debugging → Pair device with pairing code").foregroundStyle(.secondary)
            field("IP address & Port", text: $flow.pairingAddress, prompt: "192.168.1.23:37045")
            field("Pairing code", text: $flow.pairingCode, prompt: "123456")
            errorLine(error)
            Button("Pair") { flow.submitPairingCode() }
                .keyboardShortcut(.defaultAction)
        }
    }

    private func manualStep(error: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paired. The phone did not connect by itself.")
            Text("Enter the IP address & Port shown on the Wireless debugging screen.").foregroundStyle(.secondary)
            field("IP address & Port", text: $flow.manualAddress, prompt: "192.168.1.23:41234")
            errorLine(error)
            Button("Connect") { flow.submitManualAddress() }
                .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder
    private func errorLine(_ error: String?) -> some View {
        if let error {
            Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .monospaced()
        }
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text)
        }
    }
}
