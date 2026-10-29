import Foundation

/// User-editable settings. Lives at ~/.config/llm-usage-bar/config.json.
/// Codex reports official rate limits directly, so there's little to tune here.
struct Config: Codable {
    /// Fallback polling cadence; account notifications refresh immediately.
    static let refreshSeconds: TimeInterval = 60
    var providerID: UsageProviderID = .codex
    var selectedQuotaIDs: [String: String] = [:]
    var menuBarDisplayMode: MenuBarDisplayMode = .fiveHour
    var menuBarStyle: MenuBarStyle = .ring
    var percentDisplayMode: PercentDisplayMode = .remaining
    var thresholdAlertsEnabled: Bool = true
    var warningThreshold: Double = 80

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try c.decodeIfPresent(UsageProviderID.self, forKey: .providerID) ?? .codex
        selectedQuotaIDs = try c.decodeIfPresent([String: String].self, forKey: .selectedQuotaIDs) ?? [:]
        menuBarDisplayMode = try c.decodeIfPresent(MenuBarDisplayMode.self, forKey: .menuBarDisplayMode) ?? .fiveHour
        menuBarStyle = try c.decodeIfPresent(MenuBarStyle.self, forKey: .menuBarStyle) ?? .ring
        percentDisplayMode = try c.decodeIfPresent(PercentDisplayMode.self, forKey: .percentDisplayMode) ?? .remaining
        thresholdAlertsEnabled = try c.decodeIfPresent(Bool.self, forKey: .thresholdAlertsEnabled) ?? true
        warningThreshold = min(100, max(50,
            try c.decodeIfPresent(Double.self, forKey: .warningThreshold) ?? 80))
    }

    enum MenuBarStyle: String, Codable, CaseIterable, Identifiable {
        case ring, text
        var id: String { rawValue }
        var titleKey: String { "settings.menuBarStyle.\(rawValue)" }
    }

    enum MenuBarDisplayMode: String, Codable, CaseIterable, Identifiable {
        case fiveHour
        case weekly
        case highest

        var id: String { rawValue }
        static var settingsCases: [MenuBarDisplayMode] { [.fiveHour, .weekly, .highest] }

        var titleKey: String {
            switch self {
            case .fiveHour: return "settings.menuBarMode.fiveHour"
            case .weekly: return "settings.menuBarMode.weekly"
            case .highest: return "settings.menuBarMode.highest"
            }
        }
    }

    enum PercentDisplayMode: String, Codable, CaseIterable, Identifiable {
        case remaining
        case used

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .remaining: return "settings.percentMode.remaining"
            case .used: return "settings.percentMode.used"
            }
        }
    }

    static let path: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/llm-usage-bar", isDirectory: true)
        return dir.appendingPathComponent("config.json")
    }()

    static func load() -> Config {
        let url = Config.path
        guard let data = try? Data(contentsOf: url),
              let cfg = try? JSONDecoder().decode(Config.self, from: data) else {
            let def = Config()
            def.save()  // write defaults so the user has something to edit
            return def
        }
        return cfg
    }

    func selectedQuotaID(for providerID: UsageProviderID) -> String? {
        selectedQuotaIDs[providerID.rawValue]
    }

    mutating func selectQuota(_ quotaID: String, for providerID: UsageProviderID) {
        selectedQuotaIDs[providerID.rawValue] = quotaID
    }

    func save() {
        let url = Config.path
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) { try? data.write(to: url) }
    }
}
