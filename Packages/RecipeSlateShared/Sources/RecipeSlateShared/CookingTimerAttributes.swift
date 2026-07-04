import Foundation
import ActivityKit

public struct CookingTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var remainingSeconds: Int
        public var totalSeconds: Int
        public var stepLabel: String
        public var recipeName: String

        public init(
            remainingSeconds: Int,
            totalSeconds: Int,
            stepLabel: String,
            recipeName: String
        ) {
            self.remainingSeconds = remainingSeconds
            self.totalSeconds = totalSeconds
            self.stepLabel = stepLabel
            self.recipeName = recipeName
        }
    }

    public var timerId: String

    public init(timerId: String) {
        self.timerId = timerId
    }
}
