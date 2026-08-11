import Foundation

// MARK: - JSON-decodable package manifest

struct PackageManifest: Codable {
    var casks: [BrewPackage]
    var formulae: [BrewPackage]
    var pip_packages: [BrewPackage]
    var settings: InstallSettings
}

struct BrewPackage: Codable, Identifiable {
    var id: String
    var name: String
    var category: String
    var description: String
}

struct InstallSettings: Codable {
    var enable_touchid_sudo: Bool
    var configure_pip_break_system_packages: Bool
    var install_playwright_browsers: Bool
}

// MARK: - Runtime install state (not persisted)

enum PackageStatus: Equatable {
    case pending
    case installing
    case installed
    case skipped
    case failed(String)

    var icon: String {
        switch self {
        case .pending:       return "circle"
        case .installing:    return "arrow.clockwise.circle.fill"
        case .installed:     return "checkmark.circle.fill"
        case .skipped:       return "minus.circle.fill"
        case .failed:        return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .pending:       return "secondary"
        case .installing:    return "blue"
        case .installed:     return "green"
        case .skipped:       return "orange"
        case .failed:        return "red"
        }
    }
}

struct PackageInstallState: Identifiable {
    let id: String
    let name: String
    let kind: PackageKind
    var status: PackageStatus = .pending
}

enum PackageKind { case cask, formula, pip }

// MARK: - Log entry

struct LogEntry: Identifiable {
    let id = UUID()
    let level: LogLevel
    let message: String
    let timestamp: Date

    enum LogLevel { case info, ok, warn, error }
}
