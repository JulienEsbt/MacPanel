import SwiftUI

struct DisksView: View {
    @ObservedObject var disks: DiskController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Disques et espace disponible").font(.headline)
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
                    Text("\(capacity(disk.available)) disponibles sur \(capacity(disk.total))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
            }
            Text("L’espace disponible peut inclure du stockage récupérable par macOS. Plusieurs volumes APFS peuvent partager le même espace : leurs capacités ne s’additionnent pas.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = disks.error { Text(error).font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
        }.task { disks.start() }.onDisappear { disks.stop() }
    }

    private func capacity(_ bytes: Int64?) -> String {
        bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—"
    }
}

struct DisplaysView: View {
    @ObservedObject var controller: DisplayController

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
            Text("Le contrôle matériel dépend de l’écran et du câble. Active DDC/CI dans le menu de l’écran si nécessaire. MonitorControl reste installé pour comparaison.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = controller.error { Text(error).font(.callout).foregroundStyle(.orange) }
        }.task { controller.refresh() }.onDisappear { controller.stopReading() }
    }
}

private struct DisplaySlider: View {
    let display: DisplayReading
    @ObservedObject var controller: DisplayController
    @State private var value: Double = 1
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(display.name, systemImage: display.isBuiltin ? "laptopcomputer" : "display")
                .font(.callout.weight(.semibold))
            if display.brightness != nil {
                HStack {
                    Image(systemName: "sun.min")
                    Slider(value: Binding(get: { value }, set: { next in
                        value = next
                        controller.set(display, to: next)
                    }), in: (display.mode == .shade ? 0.2 : 0)...1,
                        onEditingChanged: { editing = $0 })
                        .accessibilityLabel("Luminosité de \(display.name)")
                    Image(systemName: "sun.max")
                    Text(value.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit().frame(width: 45, alignment: .trailing)
                }
                Text(display.mode == .shade ? "Atténuation visuelle : ne réduit pas le rétroéclairage. Annulée en quittant MacPanel."
                     : display.mode == .ddc ? "Luminosité matérielle · DDC/CI" : "Luminosité matérielle · Apple")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Le réglage de cet écran n’est pas disponible.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12).background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
        .onAppear { value = display.brightness ?? 1 }
        .onChange(of: display.brightness) { _, new in if !editing { value = new ?? 1 } }
    }
}
