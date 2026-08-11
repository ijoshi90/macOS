# BrewInstaller

A native macOS app that installs your Homebrew casks, formulae, and pip packages via a polished SwiftUI interface — no Terminal required.

## Features

- **Native SwiftUI** — follows Apple's design language, works on macOS 13+
- **JSON-driven** — add or remove packages by editing `packages.json`, no code changes needed
- **Live progress** — per-package status cards + animated progress bar
- **Full log** — filterable, searchable log with export to `.txt`
- **TouchID sudo** — enables `pam_tid.so` automatically
- **pip support** — installs Python packages with `--break-system-packages` pre-configured

## Getting Started

### Requirements
- macOS 13 Ventura or later
- Xcode 15+ **or** Swift toolchain (`swift build`)

### Build & run (Swift Package Manager)

```bash
git clone <your-repo>
cd BrewInstaller
swift run
```

Or build a release binary:

```bash
swift build -c release
.build/release/BrewInstaller
```

### Customise packages

Edit `packages.json` in the project root before building, or use the **Packages** tab inside the app at runtime — changes are saved back to `packages.json` instantly.

```json
{
  "casks": [
    { "id": "firefox", "name": "Firefox", "category": "Browser", "description": "Mozilla Firefox" }
  ],
  "formulae": [...],
  "pip_packages": [...],
  "settings": {
    "enable_touchid_sudo": true,
    "configure_pip_break_system_packages": true,
    "install_playwright_browsers": true
  }
}
```

| Field | Description |
|---|---|
| `id` | Exact Homebrew cask/formula name (`brew install <id>`) |
| `name` | Display name shown in the UI |
| `category` | Label badge (e.g. Development, Browser, AI) |
| `description` | One-line description shown in the Packages tab |

## Project structure

```
BrewInstaller/
├── packages.json                  ← edit this to customise installs
├── Package.swift
├── scripts/
│   └── install_core.sh            ← shell logic (called by the app)
└── Sources/BrewInstaller/
    ├── BrewInstallerApp.swift
    ├── Models/Models.swift
    ├── ViewModels/InstallerViewModel.swift
    └── Views/
        ├── ContentView.swift
        ├── InstallView.swift
        ├── PackagesView.swift
        └── LogView.swift
```

## Publishing to GitHub Pages

The app is self-contained — bundle the folder as a zip for distribution:

```bash
zip -r BrewInstaller.zip BrewInstaller/
```

Add a GitHub release and attach the zip. Users download, unzip, and run `swift run`.

## How it works

1. The app reads `packages.json` on launch.
2. On **Install All**, it shells out to `scripts/install_core.sh`, passing the JSON path.
3. The script emits tagged lines (`OK:`, `INFO:`, `PROGRESS:`, etc.) that the app parses in real time to update the UI.
4. All original logic from `install_macOS_progs.sh` lives in `install_core.sh` — nothing is duplicated.
