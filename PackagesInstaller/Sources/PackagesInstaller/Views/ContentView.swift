import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: InstallerViewModel
    @State private var selectedTab: Tab = .install

    enum Tab: String, CaseIterable {
        case install  = "Install"
        case packages = "Packages"
        case log      = "Log"

        var icon: String {
            switch self {
            case .install:  return "square.and.arrow.down.fill"
            case .packages: return "shippingbox.fill"
            case .log:      return "doc.text.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ──────────────────────────────────
            VStack(spacing: 0) {
                // App identity
                VStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.top, 28)
                    Text("Packages Installer")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("macOS Setup")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 28)

                // Nav items
                VStack(spacing: 4) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        SidebarItem(
                            icon: tab.icon,
                            label: tab.rawValue,
                            isSelected: selectedTab == tab,
                            badge: tab == .log ? vm.logEntries.filter { $0.level == .error || $0.level == .warn }.count : 0
                        )
                        .onTapGesture { selectedTab = tab }
                    }
                }
                .padding(.horizontal, 12)

                Spacer()

                // TouchID status pill
                HStack(spacing: 6) {
                    Image(systemName: vm.touchIDEnabled ? "touchid" : "touchid")
                        .foregroundStyle(vm.touchIDEnabled ? .green : .white.opacity(0.4))
                    Text(vm.touchIDEnabled ? "TouchID active" : "TouchID off")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(.white.opacity(0.08), in: Capsule())
                .padding(.bottom, 20)
            }
            .frame(width: 176)
            .background(Color(red: 0.09, green: 0.09, blue: 0.12))

            Divider()

            // ── Main content ─────────────────────────────
            Group {
                switch selectedTab {
                case .install:  InstallView()
                case .packages: PackagesView()
                case .log:      LogView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Sidebar item

struct SidebarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let badge: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            Spacer()
            if badge > 0 {
                Text("\(badge)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            isSelected
                ? Color.white.opacity(0.12)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
