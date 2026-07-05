import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget for Cooking Timer (matching Apple's AlarmLiveActivity pattern)

struct CookingAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookingAlarmMetadata>.self) { context in
            lockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    alarmTitle(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    recipeIcon
                }
                DynamicIslandExpandedRegion(.bottom) {
                    bottomContent(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                countdownText(state: context.state, maxWidth: 44)
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                AlarmProgressView(state: context.state, tint: context.attributes.tintColor)
            } minimal: {
                AlarmProgressView(state: context.state, tint: context.attributes.tintColor)
            }
            .keylineTint(context.attributes.tintColor)
        }
    }

    func lockScreenView(attributes: AlarmAttributes<CookingAlarmMetadata>, state: AlarmPresentationState) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                alarmTitle(attributes: attributes, state: state)
                Spacer()
                recipeIcon
            }
            HStack {
                countdownText(state: state, maxWidth: 150)
                    .font(.system(size: 40, design: .rounded))
                Spacer()
                AlarmControlsView(presentation: attributes.presentation, state: state)
            }
        }
        .padding(.all, 12)
    }

    @ViewBuilder
    func alarmTitle(attributes: AlarmAttributes<CookingAlarmMetadata>, state: AlarmPresentationState) -> some View {
        let title: LocalizedStringResource? = switch state.mode {
        case .countdown:
            attributes.presentation.countdown?.title
        case .paused:
            attributes.presentation.paused?.title
        default:
            nil
        }
        Text(title ?? "")
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
            .padding(.leading, 6)
    }

    var recipeIcon: some View {
        Image(systemName: "frying.pan")
            .font(.title2)
            .foregroundColor(.secondary)
            .padding(.trailing, 6)
    }

    func countdownText(state: AlarmPresentationState, maxWidth: CGFloat) -> some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
            case .paused(let pausedState):
                let remaining = Duration.seconds(
                    pausedState.totalCountdownDuration - pausedState.previouslyElapsedDuration
                )
                let pattern: Duration.TimeFormatStyle.Pattern =
                    remaining > .seconds(3600) ? .hourMinuteSecond : .minuteSecond
                Text(remaining.formatted(.time(pattern: pattern)))
            default:
                EmptyView()
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: maxWidth, alignment: .leading)
    }

    func bottomContent(attributes: AlarmAttributes<CookingAlarmMetadata>, state: AlarmPresentationState) -> some View {
        HStack {
            countdownText(state: state, maxWidth: 150)
                .font(.system(size: 40, design: .rounded))
            Spacer()
            AlarmControlsView(presentation: attributes.presentation, state: state)
        }
    }
}

// MARK: - Progress View

struct AlarmProgressView: View {
    var state: AlarmPresentationState
    var tint: Color

    var body: some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                ProgressView(
                    timerInterval: Date.now...countdown.fireDate,
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: {
                        Image(systemName: "frying.pan").scaleEffect(0.9)
                    }
                )
            case .paused(let pausedState):
                let remaining = pausedState.totalCountdownDuration - pausedState.previouslyElapsedDuration
                ProgressView(
                    value: remaining,
                    total: pausedState.totalCountdownDuration,
                    label: { EmptyView() },
                    currentValueLabel: {
                        Image(systemName: "pause.fill").scaleEffect(0.8)
                    }
                )
            default:
                EmptyView()
            }
        }
        .progressViewStyle(.circular)
        .foregroundStyle(tint)
        .tint(tint)
    }
}

// MARK: - Controls View

struct AlarmControlsView: View {
    var presentation: AlarmPresentation
    var state: AlarmPresentationState

    var body: some View {
        HStack(spacing: 4) {
            switch state.mode {
            case .countdown:
                AlarmButtonView(
                    config: presentation.countdown?.pauseButton,
                    intent: PauseTimerIntent(alarmID: state.alarmID.uuidString),
                    tint: .orange
                )
            case .paused:
                AlarmButtonView(
                    config: presentation.paused?.resumeButton,
                    intent: ResumeTimerIntent(alarmID: state.alarmID.uuidString),
                    tint: .orange
                )
            default:
                EmptyView()
            }
            AlarmButtonView(
                config: presentation.alert.stopButton,
                intent: StopTimerIntent(alarmID: state.alarmID.uuidString),
                tint: .red
            )
        }
    }
}

// MARK: - Button View

struct AlarmButtonView<I: AppIntent>: View {
    let config: AlarmButton
    let intent: I
    let tint: Color

    init?(config: AlarmButton?, intent: I, tint: Color) {
        guard let config else { return nil }
        self.config = config
        self.intent = intent
        self.tint = tint
    }

    var body: some View {
        Button(intent: intent) {
            Label(config.text, systemImage: config.systemImageName)
                .lineLimit(1)
        }
        .tint(tint)
        .buttonStyle(.borderedProminent)
        .frame(width: 96, height: 30)
    }
}
