import SwiftUI
import ActivityKit
import AudioToolbox
import RecipeSlateShared

// MARK: - CookingTimerAttributes extension (display helpers)

extension CookingTimerAttributes.ContentState {
    var displayTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "\(s)s"
    }

    var totalMinutes: Int { (totalSeconds + 59) / 60 }
}

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
            + Text(" Steps").font(.bodyText.weight(.bold)).foregroundColor(.textSecondary))
                .contentTransition(.numericText())
                .animation(.default, value: cooking.remainingSteps)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { timerSelectionMode.toggle() }) {
                Image(systemName: timerSelectionMode ? "timer.circle.fill" : "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(timerSelectionMode ? .accentOrange : .brandBlue)
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "frying.pan").font(.system(size: 40)).foregroundColor(.textTertiary)
            Text("还没有开始烹饪").font(.title3.weight(.semibold))
            Text("从食谱页右滑 Make 或点击 Start 开始").font(.calloutText).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pageBg)
    }

    // MARK: Step List

    private var stepList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(cooking.steps.enumerated()), id: \.element.id) { i, step in
                    stepCard(i: i, step: step)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
                timePills(matches: timeMatches, stepNumber: i + 1)
            }
        }
        .padding(12)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stepNumber(i: Int, completed: Bool) -> some View {
        ZStack {
            Circle().fill(completed ? Color.accentGreen : Color.brandBlue).frame(width: 28, height: 28)
            Text("\(i + 1)").font(.calloutText.weight(.bold)).foregroundColor(.white)
        }
        .padding(.top, 2)
    }

    private func stepContent(step: CookingStep, completed: Bool) -> some View {
        cookingColoredText(step.description)
            .font(.bodyText).lineSpacing(6)
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

    /// Clear shopping list on first step completion, then toggle step state.
    private func handleStepToggle(_ stepId: String) {
        if !cooking.completedStepIds.contains(stepId) && cooking.completedStepIds.isEmpty {
            store.clearShoppingList()
        }
        cooking.toggleStep(stepId)
    }

    private func timePills(matches: [String], stepNumber: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(matches, id: \.self) { match in
                Button(action: { startTimer(match: match, stepNumber: stepNumber) }) {
                    Text(match)
                        .font(.captionText.weight(.semibold))
                        .foregroundColor(.accentOrange)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.accentOrange.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 38)
        .transition(.opacity.combined(with: .scale(0.9)))
    }

    // MARK: Colored Text

    /// Highlights time (red/orange) and temperature (orange) in cooking step descriptions.
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

        // Chinese idioms
        switch trimmed {
        case "一刻", "一刻钟": return 15 * 60
        case "一会", "一会儿": return 5 * 60
        case "半天": return 12 * 3600
        case "片刻": return 2 * 60
        default: break
        }

        // Structured patterns: minutes, hours, seconds, English minutes
        let parsers: [(pattern: String, multiplier: Double)] = [
            (#"(\d+)\s*(分钟|分|m(?!i))"#, 60),
            (#"(\d+)\s*(小时|h)"#, 3600),
            (#"(\d+)\s*(秒|s(?!\w))"#, 1),
            (#"(\d+)\s*(min(?:ute)?s?|mins)"#, 60),
        ]

        for (pattern, multiplier) in parsers {
            if let r = trimmed.range(of: pattern, options: .regularExpression) {
                let s = String(trimmed[r])
                let digits = s.prefix(while: \.isNumber)
                if let n = Double(digits) { return n * multiplier }
            }
        }

        // Chinese digit time
        let chineseMap: [Character: Double] = [
            "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
            "十": 10, "半": 0.5, "几": 5
        ]
        let chineseTimePattern = #"[一二两三四五六七八九十半几]+\s*(分钟|小时|天)"#
        if trimmed.range(of: chineseTimePattern, options: .regularExpression) != nil {
            for (char, val) in chineseMap {
                if trimmed.hasPrefix(String(char)) {
                    if trimmed.contains("小时") { return val * 3600 }
                    if trimmed.contains("分钟") { return val * 60 }
                    if trimmed.contains("天") { return val * 86400 }
                }
            }
        }
        return nil
    }

    // MARK: Live Activity Timer

    private func startTimer(match: String, stepNumber: Int) {
        guard let duration = parseTimeToSeconds(match) else { return }

        timerSelectionMode = false
        let recipeName = cooking.recipeName

        Task {
            let attributes = CookingTimerAttributes(timerId: UUID().uuidString)
            let initialState = CookingTimerAttributes.ContentState(
                remainingSeconds: Int(duration),
                totalSeconds: Int(duration),
                stepLabel: "Step \(stepNumber)",
                recipeName: recipeName
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: nil)
                )

                var remaining = Int(duration)
                while remaining > 0 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    remaining -= 1
                    let state = CookingTimerAttributes.ContentState(
                        remainingSeconds: max(0, remaining),
                        totalSeconds: Int(duration),
                        stepLabel: "Step \(stepNumber)",
                        recipeName: recipeName
                    )
                    await activity.update(using: state)
                }

                await activity.end(
                    using: CookingTimerAttributes.ContentState(
                        remainingSeconds: 0,
                        totalSeconds: Int(duration),
                        stepLabel: "Step \(stepNumber)",
                        recipeName: recipeName
                    ),
                    dismissalPolicy: .after(Date(timeIntervalSinceNow: 3))
                )

                AudioServicesPlayAlertSound(1005)
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            } catch {
                print("Live Activity error: \(error)")
            }
        }
    }
}
