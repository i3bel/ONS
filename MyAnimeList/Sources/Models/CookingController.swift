import Foundation
import Observation

// MARK: - Cooking State (extracted from RecipeStore for single responsibility)

@Observable
final class CookingController {
    var steps: [CookingStep] = []
    var completedStepIds: Set<String> = []
    var recipeName: String = ""

    var remainingSteps: Int { steps.count - completedStepIds.count }
    var isActive: Bool { !steps.isEmpty }

    func startCooking(steps: [CookingStep], recipeName: String) {
        self.steps = steps
        self.completedStepIds = []
        self.recipeName = recipeName
    }

    /// Toggle step completion. Auto-clears cooking state when all steps done.
    /// Returns whether this toggle added a new completion (vs. undoing one).
    @discardableResult
    func toggleStep(_ id: String) -> Bool {
        if completedStepIds.contains(id) {
            completedStepIds.remove(id)
            return false
        } else {
            completedStepIds.insert(id)
            if completedStepIds.count == steps.count {
                steps = []
                completedStepIds = []
                recipeName = ""
            }
            return true
        }
    }

    func stopCooking() {
        steps = []
        completedStepIds = []
        recipeName = ""
    }
}
