import SwiftUI

struct InstallView: View {
    @EnvironmentObject var vm: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────
            headerSection

            ScrollView {
                VStack(spacing: 20) {
                    // Progress card
                    progressCard

                    // Package grid
                    if !vm.packageStates.isEmpty {
                        packageGrid
                    }
                }
                .padding(24)
            }

            Divider()

            // ── Action bar ───────────────────────────────
            actionBar
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Install Packages")
                        .font(.title2.bold())
                    if let manifest = vm.manifest {
                        let total = manifest.casks.count + manifest.formulae.count + manifest.pip_packages.count
                        Text("\(total) packages configured · \(manifest.casks.count) casks · \(manifest.formulae.count) formulae · \(manifest.pip_packages.count) pip")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if vm.isDone {
                    Label("Complete", systemImage: "checkmark.seal.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()
        }
    }

    // MARK: Progress card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(vm.progress * 100))%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressGradient)
                        .frame(width: geo.size.width * vm.progress, height: 12)
                        .animation(.spring(response: 0.4), value: vm.progress)
                }
            }
            .frame(height: 12)

            if !vm.currentItem.isEmpty {
                HStack(spacing: 6) {
                    if vm.isRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    }
                    Text(vm.currentItem)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Quick stats row
            if vm.isDone {
                HStack(spacing: 16) {
                    StatPill(count: vm.packageStates.filter { $0.status == .installed }.count,
                             label: "Installed", color: .green)
                    StatPill(count: vm.packageStates.filter { $0.status == .skipped }.count,
                             label: "Already present", color: .orange)
                    StatPill(count: vm.packageStates.filter { if case .failed = $0.status { return true }; return false }.count,
                             label: "Failed", color: .red)
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.12)))
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    // MARK: Package grid

    private var packageGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Packages")
                .font(.headline)

            let columns = [GridItem(.adaptive(minimum: 220), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.packageStates) { state in
                    PackageCard(state: state)
                }
            }
        }
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            if let err = vm.manifestLoadError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if vm.isRunning {
                Button(role: .destructive) {
                    vm.cancelInstall()
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    vm.startUpdate()
                } label: {
                    Label("Update All", systemImage: "arrow.triangle.2.circlepath")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(vm.manifest == nil)

                Button {
                    vm.startInstall()
                } label: {
                    Label(vm.isDone ? "Run Again" : "Install All", systemImage: "play.fill")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vm.manifest == nil)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

// MARK: - Package card

struct PackageCard: View {
    let state: PackageInstallState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.status.icon)
                .font(.system(size: 18))
                .foregroundStyle(statusColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(kindLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .installing = state.status {
                ProgressView()
                    .scaleEffect(0.65)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(statusColor.opacity(0.25)))
        .animation(.easeInOut(duration: 0.2), value: state.status)
    }

    private var statusColor: Color {
        switch state.status {
        case .pending:   return Color.secondary.opacity(0.4)
        case .installing: return .accentColor
        case .installed: return .green
        case .skipped:   return .orange
        case .failed:    return .red
        }
    }

    private var kindLabel: String {
        switch state.kind {
        case .cask:    return "Cask · brew install --cask"
        case .formula: return "Formula · brew install"
        case .pip:     return "pip package"
        }
    }
}

// MARK: - Stat pill

struct StatPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("\(count)")
                .font(.callout.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.08), in: Capsule())
    }
}
