import AlarmKit
import Foundation

// MARK: - Alarm Metadata (matching Apple's CookingData pattern)

/// Rich metadata attached to every cooking timer alarm,
/// enabling the Live Activity to display recipe context.
struct CookingAlarmMetadata: AlarmMetadata {
    let createdAt: Date
    let recipeName: String
    let stepNumber: Int

    init(recipeName: String, stepNumber: Int) {
        self.createdAt = Date.now
        self.recipeName = recipeName
        self.stepNumber = stepNumber
    }

    var label: String { "⏰ \(recipeName) — Step \(stepNumber)" }
}
