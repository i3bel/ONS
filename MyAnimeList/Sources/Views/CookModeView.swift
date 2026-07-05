import SwiftUI
import AlarmKit
import EventKit

struct CookModeView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(CookingController.self) private var cooking
    @State private var timerSelectionMode = false

    var body: some View {
        NavigationStack {
            Group {
                if cooking.steps.isEmpty {
                    emptyState
                } else {
                    stepList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onChange(of: cooking.steps.isEmpty) { _, empty in
                if empty { timerSelectionMode = false }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            (Text("\(cooking.remainingSteps)").font(.title2.weight(.bold)).foregroundColor(.textPrimary)
            + Text(" Steps").font(.body.weight(.bold)).foregroundColor(.textSecondary))
                .contentTransition(.numericText())
                .animation(.default, value: cooking.remainingSteps)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { timerSelectionMode.toggle() }) {
                Image(systemName: timerSelectionMode ? "timer.circle.fill" : "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(timerSelectionMode ? .accentOrange : .accentColor)
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Active Cook",
            systemImage: "frying.pan",
            description: Text("Swipe left on a recipe and tap Cook, or open a recipe and tap Start.")
        )
    }

    // MARK: Step List

    private var stepList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(cooking.steps.enumerated()), id: \.element.id) { i, step in
                    stepCard(i: i, step: step)
                }
            }
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, Spacing.small)
        }
        .background(Color.pageBg)
    }

    // MARK: Step Card

    private func stepCard(i: Int, step: CookingStep) -> some View {
        let completed = cooking.completedStepIds.contains(step.id)
        let timeMatches = extractTimeMatches(from: step.description)

        return VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                stepNumber(i: i, completed: completed)
                stepContent(step: step, completed: completed)
                toggleButton(step: step, completed: completed)
            }

            if timerSelectionMode && !completed && !timeMatches.isEmpty {
                timePills(matches: timeMatches, stepNumber: i + 1, stepIndex: i)
            }
        }
        .padding(12)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: CornerRadius.standard))
    }

    private func stepNumber(i: Int, completed: Bool) -> some View {
        ZStack {
            Circle().fill(completed ? Color.accentGreen : Color(.systemGray4)).frame(width: 28, height: 28)
            Text("\(i + 1)").font(.callout.weight(.bold)).foregroundColor(.white)
        }
        .padding(.top, 2)
    }

    private func stepContent(step: CookingStep, completed: Bool) -> some View {
        cookingColoredText(step.description)
            .font(.body).lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .strikethrough(completed)
            .opacity(completed ? 0.5 : 1)
            .padding(.top, 2)
    }

    private func toggleButton(step: CookingStep, completed: Bool) -> some View {
        Button(action: { handleStepToggle(step.id) }) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(completed ? .accentGreen : .textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func handleStepToggle(_ stepId: String) {
        if !cooking.completedStepIds.contains(stepId) && cooking.completedStepIds.isEmpty {
            store.clearShoppingList()
        }
        cooking.toggleStep(stepId)
    }

    // MARK: Time Pills

    private func timePills(matches: [String], stepNumber: Int, stepIndex: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(matches, id: \.self) { match in
                Button(action: { startTimer(match: match, stepNumber: stepNumber, stepIndex: stepIndex) }) {
                    Text(match)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentOrange)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.tint.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 38)
        .transition(.opacity.combined(with: .scale(0.9)))
    }

    // MARK: Colored Text

    private func cookingColoredText(_ text: String) -> Text {
        let rules: [HighlightRule] = [
            .init(
                pattern: RecipeTextPatterns.time,
                color: timerSelectionMode ? .accentOrange : .accentRed
            ),
            .init(pattern: RecipeTextPatterns.temperature, color: .accentOrange),
        ]
        return highlightText(text, rules: rules)
    }

    // MARK: Time Parsing

    private func extractTimeMatches(from text: String) -> [String] {
        var matches: [String] = []
        var remaining = text
        while let r = remaining.range(of: RecipeTextPatterns.time, options: .regularExpression) {
            matches.append(String(remaining[r]))
            remaining = String(remaining[r.upperBound...])
        }
        return matches
    }

    private func parseTimeToSeconds(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // 1. Special idioms
        switch trimmed {
        case "一刻", "一刻钟": return 15 * 60
        case "一会", "一会儿": return 5 * 60
        case "半天": return 12 * 3600
        case "片刻": return 2 * 60
        case "半个月": return 15 * 86400
        case "一个半月": return 45 * 86400
        case "半年": return 183 * 86400
        default: break
        }

        let chineseMap: [Character: Double] = [
            "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
            "十": 10, "半": 0.5, "几": 5
        ]

        // 2. Digit-based parsers (with decimal support)
        let parsers: [(pattern: String, multiplier: Double)] = [
            (#"(\d+(?:\.\d+)?)\s*(年|year)"#, 365 * 86400),
            (#"(\d+(?:\.\d+)?)\s*(周|week)"#, 7 * 86400),
            (#"(\d+(?:\.\d+)?)\s*(天|day)"#, 86400),
            (#"(\d+(?:\.\d+)?)\s*(小时|h)"#, 3600),
            (#"(\d+(?:\.\d+)?)\s*(分钟|分|m(?!i))"#, 60),
            (#"(\d+(?:\.\d+)?)\s*(秒|s(?!\w))"#, 1),
            (#"(\d+(?:\.\d+)?)\s*(min(?:ute)?s?|mins)"#, 60),
        ]

        for (pattern, multiplier) in parsers {
            if let r = trimmed.range(of: pattern, options: .regularExpression) {
                let s = String(trimmed[r])
                let digits = s.prefix(while: { $0.isNumber || $0 == "." })
                if let n = Double(digits) { return n * multiplier }
            }
        }

        // 3. Chinese "X半" patterns: "一天半", "一年半", "两天半"
        let halfPattern = #"[一两二三四五六七八九十]\s*(年|天|小时|分钟)\s*半"#
        if let r = trimmed.range(of: halfPattern, options: .regularExpression) {
            let s = String(trimmed[r])
            for (char, val) in chineseMap {
                if s.hasPrefix(String(char)) {
                    let total = val + 0.5
                    if s.contains("年") { return total * 365 * 86400 }
                    if s.contains("天") { return total * 86400 }
                    if s.contains("小时") { return total * 3600 }
                    if s.contains("分钟") { return total * 60 }
                }
            }
        }

        // 4. Pure Chinese digit patterns: "两天", "三小时"
        let chineseTimePattern = #"[一二两三四五六七八九十半几]+\s*(分钟|小时|天|年|周)"#
        if trimmed.range(of: chineseTimePattern, options: .regularExpression) != nil {
            for (char, val) in chineseMap {
                if trimmed.hasPrefix(String(char)) {
                    if trimmed.contains("年") { return val * 365 * 86400 }
                    if trimmed.contains("周") { return val * 7 * 86400 }
                    if trimmed.contains("天") { return val * 86400 }
                    if trimmed.contains("小时") { return val * 3600 }
                    if trimmed.contains("分钟") { return val * 60 }
                }
            }
        }

        return nil
    }

    // MARK: - System Timer (AlarmKit) ≤ 24h

    private func startTimer(match: String, stepNumber: Int, stepIndex: Int) {
        guard let duration = parseTimeToSeconds(match), duration > 0 else { return }
        timerSelectionMode = false

        if duration <= 86400 {
            startSystemTimer(duration: duration, stepNumber: stepNumber)
        } else {
            scheduleCalendarEvent(duration: duration, stepNumber: stepNumber)
        }
    }

    private func startSystemTimer(duration: TimeInterval, stepNumber: Int) {
        Task {
            guard await requestAlarmAuthorization() else {
                print("AlarmKit: not authorized")
                return
            }

            let metadata = CookingAlarmMetadata(
                recipeName: cooking.recipeName,
                stepNumber: stepNumber
            )

            let alertContent = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: metadata.label),
                stopButton: AlarmButton(
                    text: "Done",
                    textColor: .white,
                    systemImageName: "stop.circle"
                )
            )

            let countdownContent = AlarmPresentation.Countdown(
                title: LocalizedStringResource(stringLiteral: metadata.label),
                pauseButton: AlarmButton(
                    text: "Pause",
                    textColor: .orange,
                    systemImageName: "pause.fill"
                )
            )

            let pausedContent = AlarmPresentation.Paused(
                title: "Paused",
                resumeButton: AlarmButton(
                    text: "Resume",
                    textColor: .orange,
                    systemImageName: "play.fill"
                )
            )

            let presentation = AlarmPresentation(
                alert: alertContent,
                countdown: countdownContent,
                paused: pausedContent
            )

            let attributes = AlarmAttributes<CookingAlarmMetadata>(
                presentation: presentation,
                metadata: metadata,
                tintColor: .orange
            )

            let id = UUID()
            let config = AlarmManager.AlarmConfiguration<CookingAlarmMetadata>(
                countdownDuration: .init(preAlert: duration, postAlert: nil),
                attributes: attributes
            )

            do {
                _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
                print("AlarmKit: timer scheduled (\(Int(duration))s, step \(stepNumber))")
            } catch {
                print("AlarmKit error: \(error) (\(error.localizedDescription))")
            }
        }
    }

    private func requestAlarmAuthorization() async -> Bool {
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let state = try await AlarmManager.shared.requestAuthorization()
                return state == .authorized
            } catch {
                print("AlarmKit authorization error: \(error)")
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Calendar Event > 24h

    private func scheduleCalendarEvent(duration: TimeInterval, stepNumber: Int) {
        Task {
            let store = EKEventStore()
            do {
                let granted = try await store.requestFullAccessToEvents()
                guard granted else {
                    print("Calendar: access denied")
                    return
                }

                let event = EKEvent(eventStore: store)
                event.title = "⏰ \(cooking.recipeName) — Step \(stepNumber)"
                event.startDate = Date().addingTimeInterval(duration)
                event.endDate = event.startDate.addingTimeInterval(60)
                event.calendar = store.defaultCalendarForNewEvents
                event.alarms = [EKAlarm(absoluteDate: event.startDate)]

                try store.save(event, span: .thisEvent)
                print("Calendar: event created for \(cooking.recipeName) step \(stepNumber)")
            } catch {
                print("Calendar error: \(error.localizedDescription)")
            }
        }
    }
}
