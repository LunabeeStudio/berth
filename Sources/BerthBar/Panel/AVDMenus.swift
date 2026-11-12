import BerthCore
import SwiftUI

struct AVDMenus: View {
    let items: AVDMenuItems
    let launcher: EmulatorLauncher

    var body: some View {
        HStack(spacing: 12) {
            if !items.launch.isEmpty {
                Menu("Launch emulator") {
                    ForEach(items.launch, id: \.name) { item in
                        Button(item.title) {
                            if item.inPool { launcher.launch(model: item.name) } else { launcher.launchPlain(avd: item.name) }
                        }
                    }
                }
                .fixedSize()
            }
            if !items.prepare.isEmpty {
                Menu("Prepare AVD") {
                    ForEach(items.prepare, id: \.self) { name in
                        Button(name) { launcher.prepare(avd: name) }
                    }
                }
                .fixedSize()
            }
        }
    }
}
