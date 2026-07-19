import Combine
import Foundation

// Codable settings per PRD §8.3. JSON on disk (not UserDefaults) so users can
// read/audit the file, and because the bundle id differs between bare-executable
// and .app runs.
struct Settings: Codable, Equatable {
    var workIntervalSec: Int = 1200        // 5–120 min
    var breakDurationSec: Int = 20         // 10–120 s
    var snoozeDurationSec: Int = 180       // 1–15 min
    var idleThresholdSec: Int = 300        // 1–30 min
    var showCountdownInMenuBar: Bool = true
    var pauseUntilReenabled: Bool = false  // persisted manual quiet mode
    var quietOnFullScreen: Bool = true
    var quietOnScreenSharing: Bool = true
    var blinkReminderOn: Bool = true
    var blinkIntervalSec: Int = 600
    var warmCompressOn: Bool = false
    var warmCompressTime: String = "21:00" // "HH:mm" local
    var tearsReminderOn: Bool = false
    var tearsIntervalSec: Int = 7200       // 1–4 h
    var environmentRemindersOn: Bool = false
    var environmentTime: String = "14:00"
    var launchAtLogin: Bool = false
    var hasCompletedWelcome: Bool = false

    init() {}

    // Tolerate missing keys so old settings files survive new fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        workIntervalSec = (try? c.decode(Int.self, forKey: .workIntervalSec)) ?? d.workIntervalSec
        breakDurationSec = (try? c.decode(Int.self, forKey: .breakDurationSec)) ?? d.breakDurationSec
        snoozeDurationSec = (try? c.decode(Int.self, forKey: .snoozeDurationSec)) ?? d.snoozeDurationSec
        idleThresholdSec = (try? c.decode(Int.self, forKey: .idleThresholdSec)) ?? d.idleThresholdSec
        showCountdownInMenuBar = (try? c.decode(Bool.self, forKey: .showCountdownInMenuBar)) ?? d.showCountdownInMenuBar
        pauseUntilReenabled = (try? c.decode(Bool.self, forKey: .pauseUntilReenabled)) ?? d.pauseUntilReenabled
        quietOnFullScreen = (try? c.decode(Bool.self, forKey: .quietOnFullScreen)) ?? d.quietOnFullScreen
        quietOnScreenSharing = (try? c.decode(Bool.self, forKey: .quietOnScreenSharing)) ?? d.quietOnScreenSharing
        blinkReminderOn = (try? c.decode(Bool.self, forKey: .blinkReminderOn)) ?? d.blinkReminderOn
        blinkIntervalSec = (try? c.decode(Int.self, forKey: .blinkIntervalSec)) ?? d.blinkIntervalSec
        warmCompressOn = (try? c.decode(Bool.self, forKey: .warmCompressOn)) ?? d.warmCompressOn
        warmCompressTime = (try? c.decode(String.self, forKey: .warmCompressTime)) ?? d.warmCompressTime
        tearsReminderOn = (try? c.decode(Bool.self, forKey: .tearsReminderOn)) ?? d.tearsReminderOn
        tearsIntervalSec = (try? c.decode(Int.self, forKey: .tearsIntervalSec)) ?? d.tearsIntervalSec
        environmentRemindersOn = (try? c.decode(Bool.self, forKey: .environmentRemindersOn)) ?? d.environmentRemindersOn
        environmentTime = (try? c.decode(String.self, forKey: .environmentTime)) ?? d.environmentTime
        launchAtLogin = (try? c.decode(Bool.self, forKey: .launchAtLogin)) ?? d.launchAtLogin
        hasCompletedWelcome = (try? c.decode(Bool.self, forKey: .hasCompletedWelcome)) ?? d.hasCompletedWelcome
    }

    var schedulerConfig: BreakScheduler.Config {
        BreakScheduler.Config(
            workInterval: Double(workIntervalSec),
            breakDuration: Double(breakDurationSec),
            snoozeDuration: Double(snoozeDurationSec),
            idleThreshold: Double(idleThresholdSec)
        )
    }
}

enum AppSupport {
    /// ~/Library/Application Support/EyeBreak/ — created on first use.
    static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("EyeBreak", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

final class SettingsStore: ObservableObject {
    @Published var settings: Settings {
        didSet { save() }
    }

    private let fileURL: URL

    init(directory: URL = AppSupport.directory()) {
        fileURL = directory.appendingPathComponent("settings.json")
        settings = Self.load(from: fileURL)
    }

    private static func load(from url: URL) -> Settings {
        guard let data = try? Data(contentsOf: url) else { return Settings() }
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            // Tolerate corrupt files by regenerating defaults; never crash.
            FileHandle.standardError.write(Data("EyeBreak: settings.json unreadable, using defaults (\(error))\n".utf8))
            return Settings()
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("EyeBreak: failed to save settings (\(error))\n".utf8))
        }
    }
}
