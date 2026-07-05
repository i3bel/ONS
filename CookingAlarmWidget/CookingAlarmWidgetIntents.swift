import AlarmKit
import AppIntents
import Foundation

// MARK: - App Intents for Widget (mirrored from main app target)

struct PauseTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause"
    static let description = IntentDescription("Pause a cooking timer countdown")

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }

    func perform() throws -> some IntentResult {
        try AlarmManager.shared.pause(id: UUID(uuidString: alarmID)!)
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop"
    static let description = IntentDescription("Stop a cooking timer")

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }

    func perform() throws -> some IntentResult {
        try AlarmManager.shared.stop(id: UUID(uuidString: alarmID)!)
        return .result()
    }
}

struct ResumeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume"
    static let description = IntentDescription("Resume a paused cooking timer")

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }

    func perform() throws -> some IntentResult {
        try AlarmManager.shared.resume(id: UUID(uuidString: alarmID)!)
        return .result()
    }
}
