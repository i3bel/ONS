import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents
import RecipeSlateShared

// MARK: - CookingTimerAttributes (shared type — defined in MyAnimeList/Sources/Models/ActivityAttributes.swift)

// Extensions specific to the widget target
extension CookingTimerAttributes.ContentState {
    var displayTime: String {
        let m = remainingSeconds / 60; let s = remainingSeconds % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "\(s)s"
    }
    var displayTimeMinutes: String {
        let m = max(1, (remainingSeconds + 59) / 60)
        return "\(m) min"
    }
    var progress: Double {
        totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
    }
    var totalMinutes: Int { (totalSeconds + 59) / 60 }
}

// MARK: - Widget

struct CookingTimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookingTimerAttributes.self) { context in
            // Lock Screen / Notification Center
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Island — long press
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.recipeName)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(context.state.stepLabel) • \(context.state.totalMinutes) min")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 8)   // avoid rounded corner clipping
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        // Stop button — rounded rect
                        Button(intent: StopTimerIntent(timerId: context.attributes.timerId)) {
                            Text("Stop")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.red, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Timer — orange, same height as Stop
                        Text(context.state.displayTime)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.orange)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8) // avoid rounded corner clipping
                }
            } compactLeading: {
                Text(context.state.stepLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.leading, 4)
            } compactTrailing: {
                Text(context.state.displayTime)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.orange)
                    .monospacedDigit()
                    .padding(.trailing, 4)
            } minimal: {
                Text(context.state.displayTime)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.orange)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Lock Screen / Notification Center

struct LockScreenView: View {
    let context: ActivityViewContext<CookingTimerAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Top row: recipe name (left) + step label (right)
            HStack(alignment: .center) {
                Text(context.state.recipeName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(context.state.stepLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
            }

            // Bottom block: timer text (left) + circular stop button (right)
            HStack(spacing: 0) {
                // Left side: orange countdown text (MM:SS)
                Text(context.state.displayTime)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.orange)
                    .monospacedDigit()
                    .padding(.leading, 16)

                Spacer()

                // Right side: standalone circular stop button
                Button(intent: StopTimerIntent(timerId: context.attributes.timerId)) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.black.opacity(0.25))
            )
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.5))
    }
}

// MARK: - Stop Intent

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Timer"

    @Parameter(title: "Timer ID")
    var timerId: String
    init(timerId: String) { self.timerId = timerId }
    init() {}

    func perform() async throws -> some IntentResult {
        if let activity = Activity<CookingTimerAttributes>.activities.first(where: { $0.attributes.timerId == timerId }) {
            await activity.end(using: CookingTimerAttributes.ContentState(
                remainingSeconds: 0, totalSeconds: 0, stepLabel: "", recipeName: ""
            ), dismissalPolicy: .immediate)
        }
        return .result()
    }
}
