import SwiftUI

struct PackagesView: View {
    @EnvironmentObject var vm: InstallerViewModel
    @State private var showAddSheet   = false
    @State private var editingPackage: BrewPackage?
    @State private var editKind: PackageKind = .cask
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Package List")
                        .font(.title2.bold())
                    Text("Edit packages.json — changes are saved instantly")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Package", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isRunning)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            // Settings strip
            settingsStrip

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search packages…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            // Sections
            ScrollView {
                VStack(spacing: 20) {
                    if let manifest = vm.manifest {
                        PackageSection(
                            title: "Casks",
                            subtitle: "GUI applications · brew install --cask",
                            icon: "app.fill",
                            packages: filtered(manifest.casks),
                            kind: .cask,
                            onEdit: { p in editingPackage = p; editKind = .cask },
                            onDelete: { id in deletePackage(id: id, kind: .cask) }
                        )
                        PackageSection(
                            title: "Formulae",
                            subtitle: "CLI tools · brew install",
                            icon: "terminal.fill",
                            packages: filtered(manifest.formulae),
                            kind: .formula,
                            onEdit: { p in editingPackage = p; editKind = .formula },
                            onDelete: { id in deletePackage(id: id, kind: .formula) }
                        )
                        PackageSection(
                            title: "pip Packages",
                            subtitle: "Python packages · pip install",
                            icon: "puzzlepiece.extension.fill",
                            packages: filtered(manifest.pip_packages),
                            kind: .pip,
                            onEdit: { p in editingPackage = p; editKind = .pip },
                            onDelete: { id in deletePackage(id: id, kind: .pip) }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            PackageEditSheet(mode: .add) { kind, pkg in
                addPackage(kind: kind, package: pkg)
            }
        }
        .sheet(item: $editingPackage) { pkg in
            PackageEditSheet(mode: .edit(pkg, editKind)) { kind, updated in
                updatePackage(kind: kind, package: updated)
            }
        }
    }

    // MARK: Settings strip

    private var settingsStrip: some View {
        HStack(spacing: 24) {
            if let binding = Binding($vm.manifest) {
                Toggle(isOn: binding.settings.enable_touchid_sudo) {
                    Label("TouchID sudo", systemImage: "touchid")
                        .font(.callout)
                }
                Toggle(isOn: binding.settings.configure_pip_break_system_packages) {
                    Label("pip break-system-packages", systemImage: "gear")
                        .font(.callout)
                }
                Toggle(isOn: binding.settings.install_playwright_browsers) {
                    Label("Playwright browsers", systemImage: "globe")
                        .font(.callout)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .onChange(of: vm.manifest?.settings.enable_touchid_sudo)               { _ in vm.saveManifest() }
        .onChange(of: vm.manifest?.settings.configure_pip_break_system_packages){ _ in vm.saveManifest() }
        .onChange(of: vm.manifest?.settings.install_playwright_browsers)        { _ in vm.saveManifest() }
    }

    // MARK: Helpers

    private func filtered(_ packages: [BrewPackage]) -> [BrewPackage] {
        guard !searchText.isEmpty else { return packages }
        let q = searchText.lowercased()
        return packages.filter { $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q) || $0.category.lowercased().contains(q) }
    }

    private func addPackage(kind: PackageKind, package: BrewPackage) {
        switch kind {
        case .cask:    vm.manifest?.casks.append(package)
        case .formula: vm.manifest?.formulae.append(package)
        case .pip:     vm.manifest?.pip_packages.append(package)
        }
        vm.saveManifest()
    }

    private func updatePackage(kind: PackageKind, package: BrewPackage) {
        func update(_ arr: inout [BrewPackage]) {
            if let i = arr.firstIndex(where: { $0.id == package.id }) { arr[i] = package }
        }
        switch kind {
        case .cask:    update(&vm.manifest!.casks)
        case .formula: update(&vm.manifest!.formulae)
        case .pip:     update(&vm.manifest!.pip_packages)
        }
        vm.saveManifest()
    }

    private func deletePackage(id: String, kind: PackageKind) {
        switch kind {
        case .cask:    vm.manifest?.casks.removeAll { $0.id == id }
        case .formula: vm.manifest?.formulae.removeAll { $0.id == id }
        case .pip:     vm.manifest?.pip_packages.removeAll { $0.id == id }
        }
        vm.saveManifest()
    }
}

// MARK: - Package section

struct PackageSection: View {
    let title: String
    let subtitle: String
    let icon: String
    let packages: [BrewPackage]
    let kind: PackageKind
    let onEdit: (BrewPackage) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(packages.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }

            if packages.isEmpty {
                Text("No packages. Tap + to add one.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 1) {
                    ForEach(packages) { pkg in
                        PackageRow(package: pkg, onEdit: { onEdit(pkg) }, onDelete: { onDelete(pkg.id) })
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.12)))
            }
        }
    }
}

// MARK: - Package row

struct PackageRow: View {
    let package: BrewPackage
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name).font(.callout.weight(.medium))
                    Text(package.category)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Text(package.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                if !package.description.isEmpty {
                    Text(package.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if hovered {
                HStack(spacing: 4) {
                    Button { onEdit() } label: {
                        Image(systemName: "pencil")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .help("Edit")

                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "trash")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .help("Remove")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            hovered ? Color(NSColor.controlBackgroundColor) : Color(NSColor.windowBackgroundColor)
        )
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: hovered)
    }
}

// MARK: - Add / edit sheet

enum EditMode { case add; case edit(BrewPackage, PackageKind) }

// Forces the SwiftUI window hosting this sheet to become key so TextFields receive input
private struct KeyWindowFocusFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            v.window?.makeKeyAndOrderFront(nil)
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct PackageEditSheet: View {
    let mode: EditMode
    let onSave: (PackageKind, BrewPackage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind: PackageKind = .cask
    @State private var id          = ""
    @State private var name        = ""
    @State private var category    = ""
    @State private var description = ""

    @FocusState private var focusedField: Field?
    enum Field { case id, name, category, description }

    private var isAdd: Bool { if case .add = mode { return true }; return false }

    var body: some View {
        VStack(spacing: 0) {
            // Invisible focus fixer — zero size, no visual impact
            KeyWindowFocusFix().frame(width: 0, height: 0)

            // Sheet header
            HStack {
                Text(isAdd ? "Add Package" : "Edit Package")
                    .font(.title3.bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form
            VStack(spacing: 0) {
                Picker("Type", selection: $selectedKind) {
                    Text("Cask (GUI app)").tag(PackageKind.cask)
                    Text("Formula (CLI)").tag(PackageKind.formula)
                    Text("pip package").tag(PackageKind.pip)
                }
                .pickerStyle(.segmented)
                .disabled(!isAdd)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                VStack(spacing: 12) {
                    fieldRow(label: "Brew ID", placeholder: "e.g. visual-studio-code",
                             text: $id, field: .id, mono: true)
                    if !isAdd {
                        fieldRow(label: "Display Name", placeholder: "e.g. Visual Studio Code",
                                 text: $name, field: .name, mono: false)
                        fieldRow(label: "Category", placeholder: "e.g. Development",
                                 text: $category, field: .category, mono: false)
                        fieldRow(label: "Description", placeholder: "Short description",
                                 text: $description, field: .description, mono: false)
                    }
                }
                .padding(20)
            }

            Divider()

            // Buttons
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(isAdd ? "Add" : "Save") {
                    let pkg = BrewPackage(id: id.trimmingCharacters(in: .whitespaces),
                                         name: name.isEmpty ? id : name,
                                         category: category.isEmpty ? "Other" : category,
                                         description: description)
                    onSave(selectedKind, pkg)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(id.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(20)
        }
        .frame(width: 460)
        .onAppear {
            if case .edit(let pkg, let kind) = mode {
                id          = pkg.id
                name        = pkg.name
                category    = pkg.category
                description = pkg.description
                selectedKind = kind
            }
            // Delay slightly so the window is fully presented before grabbing focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .id
            }
        }
    }

    @ViewBuilder
    private func fieldRow(label: String, placeholder: String,
                          text: Binding<String>, field: Field, mono: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(mono ? .system(.callout, design: .monospaced) : .callout)
                .focused($focusedField, equals: field)
                .onSubmit {
                    switch field {
                    case .id:          focusedField = .name
                    case .name:        focusedField = .category
                    case .category:    focusedField = .description
                    case .description: focusedField = nil
                    }
                }
        }
    }
}
