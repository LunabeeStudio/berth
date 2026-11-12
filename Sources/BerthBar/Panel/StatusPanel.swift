import AppKit
import BerthCore
import SwiftUI

struct StatusPanel: View {
    let model: StatusModel
    @Bindable var launchAtLogin: LaunchAtLogin
    @Bindable var autoUpdate: AutoUpdateSetting
    let launcher: EmulatorLauncher
    let avdList: AVDList
    let mirror: MirrorController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.state {
            case .connecting:
                Text("connecting…").font(.headline)
            case let .live(snapshot):
                content(snapshot)
            case let .disconnected(reason):
                Text("daemon not running").font(.headline)
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            HStack(spacing: 16) {
                Toggle("Launch at login", isOn: $launchAtLogin.isEnabled)
                    .toggleStyle(.checkbox)
                Toggle("Auto update", isOn: $autoUpdate.isEnabled)
                    .toggleStyle(.checkbox)
                    .disabled(!autoUpdate.isAvailable)
                    .help(autoUpdate.isManagedByHomebrew ? "Updated by Homebrew: brew upgrade berth" : "")
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 650)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func content(_ snapshot: StateSnapshot) -> some View {
        Text(snapshot.summary)
            .font(.headline)
        if let notice = snapshot.adbNotice(now: model.now) {
            Text(notice).font(.caption).foregroundStyle(.orange)
        }
        Text("Emulators").font(.subheadline.bold())
        if snapshot.slots.isEmpty {
            Text("none running").foregroundStyle(.secondary)
        }
        ForEach(snapshot.slots) { slot in
            EmulatorRow(slot: slot, now: model.now, pool: snapshot.pool, launcher: launcher, mirror: mirror)
        }
        Text("Devices").font(.subheadline.bold())
        if snapshot.devices.isEmpty {
            Text("none connected").foregroundStyle(.secondary)
        }
        ForEach(snapshot.devices) { device in
            DeviceRow(device: device, mirror: mirror)
        }
        Text("Queue").font(.subheadline.bold())
        if snapshot.queue.isEmpty {
            Text("empty").foregroundStyle(.secondary)
        }
        ForEach(Array(snapshot.queue.enumerated()), id: \.element.id) { index, waiter in
            QueueRow(position: index + 1, waiter: waiter, now: model.now)
        }
        menus(snapshot.pool)
    }

    @ViewBuilder
    private func menus(_ pool: [PoolEntry]) -> some View {
        AVDMenus(items: AVDMenuItems(avds: avdList.avds, pool: pool), launcher: launcher)
        if let error = launcher.error {
            Text(error).font(.caption).foregroundStyle(.secondary)
        }
        if let caption = mirror.caption {
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}
