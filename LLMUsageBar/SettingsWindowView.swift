import SwiftUI
import ServiceManagement

struct GeneralSettingsTab: View {
    private let onChange: (Config) -> Void
    @State private var config: Config
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var appLanguage = GeneralSettingsTab.normalizedLanguage(
        (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])?.first)
    @State private var showRestartAlert = false

    private let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("zh-Hans", "简体中文")
    ]

    /// macOS's AppleLanguages entries carry region/script suffixes (e.g.
    /// "zh-Hans-CN", "en-US") that never exactly match our two supported
    /// picker tags ("en", "zh-Hans"), which left the Picker showing no
    /// selection. Match by leading language subtag instead.
    private static func normalizedLanguage(_ raw: String?) -> String {
        guard let raw else { return "en" }
        return raw.hasPrefix("zh") ? "zh-Hans" : "en"
    }

    init(config: Config, onChange: @escaping (Config) -> Void) {
        self.onChange = onChange
        _config = State(initialValue: config)
    }

    var body: some View {
        Form {
            Section(header: Text("settings.section.startup")) {
                Toggle("settings.launchAtLogin", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in applyLaunchAtLogin(newValue) }
            }

            Section(header: Text("settings.section.appearance")) {
                Picker("settings.menuBarStyle", selection: Binding(
                    get: { config.menuBarStyle },
                    set: { updateConfig(\.menuBarStyle, $0) }
                )) {
                    ForEach(Config.MenuBarStyle.allCases) { style in
                        Text(LocalizedStringKey(style.titleKey)).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Picker("settings.language", selection: $appLanguage) {
                    ForEach(languages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: appLanguage) { newValue in
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    showRestartAlert = true
                }
            }
            Section(header: Text("settings.section.alerts")) {
                Toggle("settings.thresholdAlerts", isOn: Binding(
                    get: { config.thresholdAlertsEnabled },
                    set: { updateConfig(\.thresholdAlertsEnabled, $0) }
                ))

                HStack {
                    Text("settings.warningThreshold")
                    Spacer()
                    Text("\(Int(config.warningThreshold.rounded()))%")
                        .foregroundStyle(.secondary)
                    Stepper("", value: Binding(
                        get: { Int(config.warningThreshold.rounded()) },
                        set: { updateConfig(\.warningThreshold, Double($0)) }
                    ), in: 50...100, step: 5)
                    .labelsHidden()
                }
                .disabled(!config.thresholdAlertsEnabled)

            }

        }
        .font(OrbTypography.swiftUIRegular(13))
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .alert(
            LocalizedStringKey("settings.restartTitle"),
            isPresented: $showRestartAlert
        ) {
            Button(LocalizedStringKey("settings.restartButton"), role: .destructive) {
                restartApp()
            }
            Button(LocalizedStringKey("action.cancel"), role: .cancel) {}
        } message: {
            Text("settings.restartMessage")
        }
    }

    private func updateConfig<Value>(_ keyPath: WritableKeyPath<Config, Value>, _ value: Value) {
        config[keyPath: keyPath] = value
        onChange(config)
    }

    private func applyLaunchAtLogin(_ enable: Bool) {
        do {
            if enable { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func restartApp() {
        let bundlePath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; open \"\(bundlePath)\""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        try? proc.run()

        NSApp.terminate(nil)
    }
}

struct AboutTab: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)

            Text("Orb")
                .font(OrbTypography.swiftUIEmphasized(22))
            Text(String(format: "about.versionBuild".l10n, version, build))
                .foregroundStyle(.secondary)
                .font(OrbTypography.swiftUIRegular(13))

            Divider()
                .frame(width: 150)
                .padding(.vertical, 2)

            HStack(spacing: 8) {
                Link("Twitter / X", destination: URL(string: "https://x.com/yasashii_me")!)
                Text("·")
                    .foregroundStyle(.tertiary)
                Link("GitHub", destination: URL(string: "https://github.com/murphy-lyu/orb-mac")!)
            }
            .font(OrbTypography.swiftUIRegular(12))

            Text("@Murphy")
                .font(OrbTypography.swiftUIRegular(11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
