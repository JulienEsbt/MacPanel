import SwiftUI

struct DisksView: View {
    @ObservedObject var disks: DiskController
    @State private var confirmEjection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Disques et espace disponible").font(.headline)
            if disks.volumes.contains(where: \.canEject) {
                Button("Éjecter tous les volumes externes…", systemImage: "eject") { confirmEjection = true }
                    .disabled(disks.ejecting != nil)
                    .confirmationDialog("Éjecter tous les volumes externes compatibles ?", isPresented: $confirmEjection) {
                        Button("Tout éjecter") { disks.ejectAll() }
                        Button("Annuler", role: .cancel) {}
                    } message: { Text("Les disques occupés seront laissés en place. Aucun démontage forcé.") }
            }
            if disks.volumes.isEmpty { Text("Lecture des volumes…").foregroundStyle(.secondary) }
            ForEach(disks.volumes) { disk in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(disk.name, systemImage: disk.isInternal == true ? "internaldrive" : "externaldrive").font(.callout.weight(.semibold))
                        Spacer()
                        Button { disks.open(disk) } label: { Image(systemName: "folder") }
                            .help("Ouvrir \(disk.name) dans Finder").accessibilityLabel("Ouvrir \(disk.name)")
                        if disk.canEject {
                            Button { disks.eject(disk) } label: { Image(systemName: "eject") }
                                .disabled(disks.ejecting != nil)
                                .help("Éjecter \(disk.name)").accessibilityLabel("Éjecter \(disk.name)")
                        }
                    }
                    if let used = disk.usedFraction { ProgressView(value: used).tint(used > 0.9 ? .orange : .blue) }
                    Text("\(capacity(disk.used)) utilisés sur \(capacity(disk.total))")
                        .font(.callout.weight(.medium)).monospacedDigit()
                    Text("\(capacity(disk.available)) libres")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                .padding(12).background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
            }
            Text("L’espace utilisé inclut les données que macOS peut éventuellement récupérer. Plusieurs volumes APFS peuvent partager le même espace : leurs capacités ne s’additionnent pas.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = disks.error { Text(error).font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
            if let notice = disks.notice { Label(notice, systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary) }
        }.task { disks.start() }.onDisappear { disks.stop() }
    }

    private func capacity(_ bytes: Int64?) -> String {
        bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—"
    }
}

struct DisplaysView: View {
    @ObservedObject var controller: DisplayController
    @ObservedObject var keyboard: BrightnessKeys

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Luminosité des écrans").font(.headline)
                Spacer()
                Button { controller.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Actualiser les écrans et la luminosité").accessibilityLabel("Actualiser les écrans")
                    .disabled(controller.busy)
            }
            if controller.displays.isEmpty { Text("Recherche des écrans…").foregroundStyle(.secondary) }
            ForEach(controller.displays) { display in
                DisplaySlider(display: display, controller: controller)
            }
            Text("Le contrôle matériel dépend de l’écran et du câble. Active DDC/CI dans le menu de l’écran si nécessaire.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = controller.error { Text(error).font(.callout).foregroundStyle(.orange) }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Lier les curseurs de luminosité", isOn: Binding(
                    get: { controller.syncEnabled }, set: { controller.setSyncEnabled($0) }))
                Text("Un curseur règle les deux écrans. Les touches du Mac pilotent aussi le groupe.")
                    .font(.caption).foregroundStyle(.secondary)
                    .help("Les écarts se règlent séparément et restent fixes. Des pourcentages identiques ne donnent pas forcément le même rendu. Arrêt en veille/verrouillage.")
                if controller.syncEnabled && !controller.displays.contains(where: { $0.isBuiltin && $0.brightness != nil }) {
                    Text("En attente d’un écran intégré disponible.").font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Toggle("Raccourcis de luminosité externe", isOn: Binding(
                    get: { keyboard.enabled }, set: { value in keyboard.configure(value) }))
                    .help("Fonctionne panneau fermé, sans autorisation supplémentaire. Les touches habituelles restent gérées par macOS.")
                Text("⌃⌥↑ / ↓ : éclaircir ou assombrir les écrans externes.")
                    .font(.caption).foregroundStyle(.secondary)
                if keyboard.enabled {
                    Label(keyboard.active ? "Raccourcis actifs" : "Raccourcis indisponibles", systemImage: keyboard.active ? "checkmark.circle" : "exclamationmark.circle")
                        .font(.caption).foregroundStyle(keyboard.active ? Color.secondary : Color.orange)
                    if !controller.hasKeyboardTarget { Text("Aucun écran externe réglable détecté.").font(.caption).foregroundStyle(.secondary) }
                    if !keyboard.active { Button("Réessayer") { keyboard.resume(); controller.refresh() } }
                }
                if let error = keyboard.error { Text(error).font(.caption).foregroundStyle(.orange) }
            }.padding(12).background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
        }.task { keyboard.resume(); controller.refresh() }
    }
}

private struct DisplaySlider: View {
    let display: DisplayReading
    @ObservedObject var controller: DisplayController
    @State private var value: Double = 1
    @State private var editing = false
    @State private var volume: Double = 0
    @State private var editingVolume = false
    private var range: ClosedRange<Double> { controller.brightnessRange(for: display) }
    private var shownValue: Double { min(range.upperBound, max(range.lowerBound, value)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(display.name, systemImage: display.isBuiltin ? "laptopcomputer" : "display")
                .font(.callout.weight(.semibold))
            if display.brightness != nil {
                HStack {
                    Image(systemName: "sun.min")
                    Slider(value: Binding(get: { shownValue }, set: { next in
                        value = next
                        controller.set(display, to: next)
                    }), in: range,
                        onEditingChanged: { editing = $0 })
                        .accessibilityLabel("Luminosité de \(display.name)")
                    Image(systemName: "sun.max")
                    Text(shownValue.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit().frame(width: 45, alignment: .trailing)
                }
                Text(display.mode == .shade ? "Atténuation visuelle : ne réduit pas le rétroéclairage. Annulée en quittant MacPanel."
                     : display.mode == .ddc ? "Luminosité matérielle · DDC/CI" : "Luminosité matérielle · Apple")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Le réglage de cet écran n’est pas disponible.").font(.caption).foregroundStyle(.secondary)
            }
            if !display.isBuiltin && controller.syncEnabled && display.brightness != nil {
                Stepper(value: Binding(get: { controller.offset(for: display) },
                    set: { controller.setOffset($0, for: display) }), in: -0.5...0.5, step: 0.01) {
                    Text(String(format: "Écart fixe : %+.0f points", controller.offset(for: display) * 100))
                        .font(.caption).monospacedDigit()
                }
                .accessibilityLabel("Écart fixe de luminosité de \(display.name)")
                .help("−/+ change uniquement cet écart. Les curseurs de luminosité le conservent. L’écart visible peut diminuer aux limites de réglage de chaque écran.")
            }
            if !display.isBuiltin {
                if display.volume != nil {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: Binding(get: { volume }, set: { next in volume = next; controller.setVolume(display, to: next) }),
                               in: 0...1, onEditingChanged: { editingVolume = $0 })
                            .accessibilityLabel("Volume des haut-parleurs de \(display.name)")
                        Text(volume.formatted(.percent.precision(.fractionLength(0)))).font(.caption).monospacedDigit().frame(width: 45)
                    }
                    Text("Haut-parleurs de l’écran · DDC/CI. Ne change pas la sortie audio du Mac.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12).background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
        .onAppear { value = display.brightness ?? 1; volume = display.volume ?? 0 }
        .onChange(of: display.brightness) { _, new in if !editing { value = new ?? 1 } }
        .onChange(of: display.volume) { _, new in if !editingVolume { volume = new ?? 0 } }
    }
}
