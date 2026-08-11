import Foundation
import Combine

@MainActor
final class InstallerViewModel: ObservableObject {

    // ── Published state ───────────────────────────────────
    @Published var manifest: PackageManifest?
    @Published var packageStates: [PackageInstallState] = []
    @Published var logEntries: [LogEntry] = []
    @Published var isRunning   = false
    @Published var isDone      = false
    @Published var progress    = 0.0          // 0…1
    @Published var currentItem = ""
    @Published var touchIDEnabled = false
    @Published var manifestLoadError: String?

    // ── File paths ────────────────────────────────────────
    private let jsonURL: URL
    private let scriptURL: URL

    // ── Process handle ────────────────────────────────────
    private var process: Process?

    init() {
        // Bundle.module resolves correctly for any SPM target name
        let resourceURL = Bundle.module.resourceURL ?? Bundle.module.bundleURL
        jsonURL   = resourceURL.appendingPathComponent("packages.json")
        scriptURL = resourceURL.appendingPathComponent("install_core.sh")

        loadManifest()
        checkTouchID()
    }

    // MARK: - Manifest

    func loadManifest() {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            manifestLoadError = "packages.json not found at \(jsonURL.path)"
            return
        }
        do {
            let data = try Data(contentsOf: jsonURL)
            manifest = try JSONDecoder().decode(PackageManifest.self, from: data)
            rebuildPackageStates()
            manifestLoadError = nil
        } catch {
            manifestLoadError = "Failed to parse packages.json: \(error.localizedDescription)"
        }
    }

    func saveManifest() {
        guard let manifest else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)
            try data.write(to: jsonURL, options: .atomic)
            rebuildPackageStates()
        } catch {
            appendLog(.error, "Failed to save packages.json: \(error.localizedDescription)")
        }
    }

    private func rebuildPackageStates() {
        guard let manifest else { return }
        var states: [PackageInstallState] = []
        manifest.casks.forEach       { states.append(PackageInstallState(id: $0.id, name: $0.name, kind: .cask)) }
        manifest.formulae.forEach    { states.append(PackageInstallState(id: $0.id, name: $0.name, kind: .formula)) }
        manifest.pip_packages.forEach{ states.append(PackageInstallState(id: $0.id, name: $0.name, kind: .pip)) }
        packageStates = states
    }

    // MARK: - TouchID check

    func checkTouchID() {
        let paths = ["/etc/pam.d/sudo", "/etc/pam.d/sudo_local"]
        touchIDEnabled = paths.contains {
            (try? String(contentsOfFile: $0, encoding: .utf8))?.contains("pam_tid.so") == true
        }
    }

    // MARK: - Install

    func startInstall() {
        guard !isRunning else { return }
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            appendLog(.error, "install_core.sh not found at \(scriptURL.path)")
            return
        }

        isRunning  = true
        isDone     = false
        progress   = 0
        currentItem = "Starting…"
        logEntries = []
        rebuildPackageStates()

        let total = Double(packageStates.filter { $0.kind != .pip }.count)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["bash", scriptURL.path, jsonURL.path]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let raw = handle.availableData
            guard !raw.isEmpty, let text = String(data: raw, encoding: .utf8) else { return }
            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                Task { @MainActor in self.parseLine(line, total: total) }
            }
        }

        proc.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                guard let self else { return }
                pipe.fileHandleForReading.readabilityHandler = nil
                self.isRunning   = false
                self.isDone      = true
                self.progress    = 1.0
                self.currentItem = p.terminationStatus == 0 ? "Complete ✓" : "Finished with errors"
                self.checkTouchID()
                if p.terminationStatus != 0 {
                    self.appendLog(.warn, "Script exited with status \(p.terminationStatus)")
                }
            }
        }

        process = proc
        do {
            try proc.run()
        } catch {
            isRunning = false
            appendLog(.error, "Failed to launch script: \(error.localizedDescription)")
        }
    }

    func cancelInstall() {
        process?.terminate()
        isRunning   = false
        currentItem = "Cancelled"
        appendLog(.warn, "Installation cancelled by user.")
    }

    // MARK: - Line parser

    private func parseLine(_ line: String, total: Double) {
        if line.hasPrefix("PROGRESS:") {
            let parts = line.dropFirst("PROGRESS:".count).components(separatedBy: ":")
            if parts.count >= 3,
               let step = Double(parts[0]),
               let tot  = Double(parts[1]) {
                let label = parts[2...].joined(separator: ":")
                progress    = tot > 0 ? min(step / tot, 1.0) : 0
                currentItem = label
                markInstalling(id: label)
            }
        } else if line.hasPrefix("OK: ") {
            let msg = String(line.dropFirst(4))
            appendLog(.ok, msg)
            markDone(message: msg)
        } else if line.hasPrefix("WARN: ") {
            appendLog(.warn, String(line.dropFirst(6)))
        } else if line.hasPrefix("ERROR: ") {
            let msg = String(line.dropFirst(7))
            appendLog(.error, msg)
            markFailed(message: msg)
        } else if line.hasPrefix("INFO: ") {
            appendLog(.info, String(line.dropFirst(6)))
        } else if line == "DONE:" {
            progress = 1.0
            isDone   = true
        }
    }

    private func markInstalling(id: String) {
        if let i = packageStates.firstIndex(where: { id.contains($0.id) }) {
            packageStates[i].status = .installing
        }
    }

    private func markDone(message: String) {
        for i in packageStates.indices {
            if message.lowercased().contains(packageStates[i].id.lowercased()) {
                switch packageStates[i].status {
                case .installing, .pending:
                    packageStates[i].status = message.contains("already") ? .skipped : .installed
                default: break
                }
            }
        }
    }

    private func markFailed(message: String) {
        for i in packageStates.indices {
            if message.lowercased().contains(packageStates[i].id.lowercased()),
               packageStates[i].status == .installing {
                packageStates[i].status = .failed(message)
            }
        }
    }

    private func appendLog(_ level: LogEntry.LogLevel, _ message: String) {
        logEntries.append(LogEntry(level: level, message: message, timestamp: Date()))
    }
}
