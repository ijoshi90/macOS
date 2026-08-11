import SwiftUI

struct LogView: View {
    @EnvironmentObject var vm: InstallerViewModel
    @State private var filterLevel: LogFilter = .all
    @State private var searchText = ""
    @State private var autoscroll = true

    enum LogFilter: String, CaseIterable {
        case all    = "All"
        case ok     = "OK"
        case info   = "Info"
        case warn   = "Warnings"
        case error  = "Errors"

        func matches(_ entry: LogEntry) -> Bool {
            switch self {
            case .all:   return true
            case .ok:    return entry.level == .ok
            case .info:  return entry.level == .info
            case .warn:  return entry.level == .warn
            case .error: return entry.level == .error
            }
        }
    }

    private var filtered: [LogEntry] {
        vm.logEntries.filter { entry in
            filterLevel.matches(entry) &&
            (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installation Log")
                        .font(.title2.bold())
                    Text("\(vm.logEntries.count) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    vm.logEntries.removeAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(vm.logEntries.isEmpty)

                Button {
                    exportLog()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(vm.logEntries.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            // Filter + search bar
            HStack(spacing: 12) {
                Picker("Filter", selection: $filterLevel) {
                    ForEach(LogFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 380)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search log…", text: $searchText).textFieldStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                Toggle(isOn: $autoscroll) {
                    Text("Auto-scroll")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            Divider()

            // Log entries
            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text(vm.logEntries.isEmpty ? "No log entries yet.\nRun an installation to see output here." : "No entries match the current filter.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filtered) { entry in
                                LogRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: filtered.count) { _ in
                        if autoscroll, let last = filtered.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func exportLog() {
        let content = vm.logEntries.map { entry in
            let ts = ISO8601DateFormatter().string(from: entry.timestamp)
            let tag = String(describing: entry.level).uppercased()
            return "[\(ts)] [\(tag)] \(entry.message)"
        }.joined(separator: "\n")

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "brew_installer_log.txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Log row

struct LogRow: View {
    let entry: LogEntry
    @State private var hovered = false

    private var levelColor: Color {
        switch entry.level {
        case .ok:    return .green
        case .info:  return .secondary
        case .warn:  return .orange
        case .error: return .red
        }
    }

    private var levelIcon: String {
        switch entry.level {
        case .ok:    return "checkmark.circle.fill"
        case .info:  return "info.circle.fill"
        case .warn:  return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var levelTag: String {
        switch entry.level {
        case .ok:    return " OK  "
        case .info:  return "INFO "
        case .warn:  return "WARN "
        case .error: return "ERROR"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Timestamp
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            // Level badge
            Text(levelTag)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(levelColor)
                .frame(width: 42)

            // Message
            Text(entry.message)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(entry.level == .error ? .red : entry.level == .warn ? .orange : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(
            hovered
                ? Color(NSColor.controlBackgroundColor)
                : (entry.level == .error
                    ? Color.red.opacity(0.05)
                    : entry.level == .warn
                        ? Color.orange.opacity(0.04)
                        : Color.clear)
        )
        .onHover { hovered = $0 }
    }
}
