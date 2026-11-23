import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class LoginSettings: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var needsApproval = false
    @Published var error: String?

    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
    }

    func set(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch { self.error = error.localizedDescription }
        refresh()
    }
}

struct PanelView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var controls: SystemControls
    @ObservedObject var awake: AwakeSession
    @ObservedObject var login: LoginSettings
    @ObservedObject var disks: DiskController
    @ObservedObject var displays: DisplayController
    @ObservedObject var shortcut: PanelShortcut
    @State private var duration = 30
    @State private var awakeError: String?
    @State private var section = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Vue", selection: $section) {
                Text("Système").tag(0)
                Text("Écrans").tag(1)
                Text("Disques").tag(2)
            }.pickerStyle(.segmented).padding(.horizontal, 18).padding(.top, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if section == 0 {
                    metrics
                    telemetry
                    commands
                    awakeSection
                    startup
                    Picker("Raccourci", selection: Binding(get: { shortcut.selection }, set: shortcut.configure)) {
                        ForEach(PanelShortcut.labels.indices, id: \.self) { index in
                            Text(PanelShortcut.labels[index]).tag(index)
                        }
                    }.font(.callout).help("Ouvre ou referme le panneau depuis une autre application. Aucune lecture des frappes.")
                    if let error = controls.error ?? awakeError ?? login.error ?? shortcut.error {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.callout).fixedSize(horizontal: false, vertical: true)
                            Button("Actualiser l’état") { controls.refresh(); login.refresh() }
                                .disabled(controls.busy)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityElement(children: .contain)
                    }
                    } else if section == 1 {
                        DisplaysView(controller: displays)
                    } else {
                        DisksView(disks: disks)
                    }
                }
                .padding(18)
            }
            Divider()
            HStack {
                Label("Local · 0.2.0", systemImage: "checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quitter") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).font(.callout)
                    .keyboardShortcut("q", modifiers: .command)
            }.padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 392, height: 638)
        .background(.regularMaterial)
        .tint(.blue)
    }

    private var telemetry: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Pression mémoire", systemImage: "memorychip")
                Spacer()
                Text(monitor.snapshot.memoryPressure?.title ?? "—")
                    .foregroundStyle(monitor.snapshot.memoryPressure == .critical ? Color.red : monitor.snapshot.memoryPressure == .warning ? .orange : .primary)
            }
            HStack {
                Label("Réseau", systemImage: "network")
                Spacer()
                Text("↓ \(rate(monitor.snapshot.download))   ↑ \(rate(monitor.snapshot.upload))").monospacedDigit()
            }
        }.font(.caption)
        .help("Pression mémoire publiée par macOS. Réseau : trafic Wi-Fi/Ethernet local, VPN non compté deux fois ; ce n’est pas un test de débit Internet.")
    }

    private func rate(_ bytes: Double?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(min(bytes, Double(Int64.max - 1024))), countStyle: .file) + "/s"
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .medium)).foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("MacPanel").font(.title3.weight(.semibold))
                Text("Votre Mac, à portée de main").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MetricView(title: "CPU", symbol: "cpu", value: percent(monitor.snapshot.cpu),
                           fraction: monitor.snapshot.cpu.map { $0 / 100 }, color: .blue)
                    .help("Utilisation globale du processeur sur les deux dernières secondes. La première valeur nécessite deux mesures.")
                MetricView(title: "RAM", symbol: "memorychip", value: memory,
                    fraction: monitor.snapshot.memoryUsed.map { Double($0) / Double(monitor.snapshot.memoryTotal) }, color: .orange)
                    .help("Mémoire unifiée utilisée estimée, cache fichiers déduit. Le GPU partage cette mémoire. Total : \(ByteCountFormatter.string(fromByteCount: Int64(monitor.snapshot.memoryTotal), countStyle: .memory)).")
                MetricView(title: "GPU", symbol: "square.3.layers.3d", value: percent(monitor.snapshot.gpu),
                           fraction: monitor.snapshot.gpu.map { $0 / 100 }, color: .green)
                    .help("Activité publiée par le pilote graphique. Un tiret signifie que le compteur n’est pas disponible, pas que l’activité est nulle.")
            }
            Text("Mesures toutes les 2 s, uniquement dans ce panneau.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var commands: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMMANDES RAPIDES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(QuickSwitch.allCases) { control in
                    Toggle(isOn: Binding(get: { controls.values[control] ?? false },
                        set: { controls.set(control, to: $0) })) {
                        Label(control.title, systemImage: control.symbol)
                            .font(.callout)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(controls.busy || controls.values[control] == nil)
                    .help(controls.values[control] == nil && control == .muted
                        ? "La sortie audio actuelle ne permet pas cette commande." : control.help)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    if control != QuickSwitch.allCases.last { Divider().padding(.leading, 12) }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var awakeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Maintien éveillé", systemImage: "cup.and.saucer").font(.callout.weight(.medium))
                Spacer()
                if awake.deadline == nil {
                    Picker("Durée du maintien éveillé", selection: $duration) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("1 h").tag(60)
                    }.labelsHidden().frame(width: 84).controlSize(.small)
                    Button("Activer") {
                        do { try awake.start(minutes: duration); awakeError = nil }
                        catch { awakeError = error.localizedDescription }
                    }.controlSize(.small)
                } else {
                    Button("Arrêter") { awake.stop(); awakeError = nil }.controlSize(.small)
                }
            }
            if let deadline = awake.deadline {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = max(0, Int(deadline.timeIntervalSince(context.date)))
                    Text("Actif · encore \(seconds / 60) min \(seconds % 60) s")
                        .monospacedDigit().font(.caption).foregroundStyle(.blue)
                }
            } else {
                Text("Mac et écran éveillés temporairement.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Arrêt au verrouillage ou en quittant. La veille manuelle et la fermeture du capot restent prioritaires.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var startup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Ouvrir à la connexion", isOn: Binding(get: { login.enabled }, set: login.set))
                .toggleStyle(.switch).controlSize(.small).font(.callout)
                .help("Démarre MacPanel dans la barre des menus, sans ouvrir le panneau.")
            if login.needsApproval {
                Button("Autoriser dans les réglages macOS…") { SMAppService.openSystemSettingsLoginItems() }
                    .font(.caption)
            }
        }
    }

    private func percent(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(0))) + " %" } ?? "—"
    }

    private var memory: String {
        monitor.snapshot.memoryUsed.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .memory) } ?? "—"
    }
}

private struct MetricView: View {
    let title: String
    let symbol: String
    let value: String
    let fraction: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.75)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.09))
                    if let fraction { Capsule().fill(color).frame(width: geometry.size.width * min(1, max(0, fraction))) }
                }
            }.frame(height: 4).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value == "—" ? "mesure indisponible" : value)")
    }
}
