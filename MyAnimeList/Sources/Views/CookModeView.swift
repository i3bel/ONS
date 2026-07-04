import SwiftUI
import ActivityKit
import AudioToolbox
import RecipeSlateShared

// MARK: - CookingTimerAttributes extensions (shared type defined in Models/)

extension CookingTimerAttributes.ContentState {
    var displayTime: String {
        let m = remainingSeconds / 60; let s = remainingSeconds % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "\(s)s"
    }
    var totalMinutes: Int { (totalSeconds + 59) / 60 }
}

struct CookModeView: View {
    @Environment(RecipeStore.self) private var store
    @State private var timerSelectionMode = false

    private var timePattern: String {
        #"(?:\d+\s*(?:min(?:ute)?s?|mins|秒|hour(?:s)?|分钟|小时|分|天|周|个月|年))|(?:[一两二三四五六七八九十半几数]+\s*(?:分钟|小时|天|周|个月|年))|一刻|一会|一会儿|片刻|半天|半个月|半年|半日|数日"#
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cookingSteps.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(store.cookingSteps.enumerated()), id: \.element.id) { i, step in
                                stepCard(i: i, step: step)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color.bgSecondary)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    (Text("\(store.remainingSteps)").font(.title2.weight(.bold)).foregroundColor(.textPrimary)
                    + Text(" Steps").font(.bodyText.weight(.bold)).foregroundColor(.textSecondary))
                        .contentTransition(.numericText())
                        .animation(.default, value: store.remainingSteps)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { timerSelectionMode.toggle() }) {
                        Image(systemName: timerSelectionMode ? "timer.circle.fill" : "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(timerSelectionMode ? .accentOrange : .brandBlue)
                    }
                }
            }
            .onChange(of: store.cookingSteps.isEmpty) { _, empty in if empty { timerSelectionMode = false } }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "frying.pan").font(.system(size: 40)).foregroundColor(.textTertiary)
            Text("还没有开始烹饪").font(.title3.weight(.semibold))
            Text("从食谱页右滑 Make 或点击 Start 开始").font(.calloutText).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgSecondary)
    }

    // MARK: - Step Card

    private func stepCard(i: Int, step: CookingStep) -> some View {
        let completed = store.completedStepIds.contains(step.id)
        let timeMatches = extractTimeMatches(from: step.description)
        return VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle().fill(completed ? Color.accentGreen : Color.brandBlue).frame(width: 28, height: 28)
                    Text("\(i + 1)").font(.calloutText.weight(.bold)).foregroundColor(.white)
                }
                .padding(.top, 2)

                cookingColoredText(step.description)
                    .font(.bodyText).lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .strikethrough(completed)
                    .opacity(completed ? 0.5 : 1)
                    .padding(.top, 2)

                Button(action: { store.toggleStep(step.id) }) {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(completed ? .accentGreen : .textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            // Tappable time pills in timer selection mode
            if timerSelectionMode && !completed && !timeMatches.isEmpty {
                HStack(spacing: 6) {
                    ForEach(timeMatches, id: \.self) { match in
                        Button(action: { startTimer(match: match, stepNumber: i + 1) }) {
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
        }
        .padding(12)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Colored Text

    private func cookingColoredText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text
        let tempPattern = #"\d+\s*(°[FC]|度)"#

        while !remaining.isEmpty {
            var earliestStart = remaining.endIndex
            var earliestRange: Range<String.Index>?
            var earliestColor: Color?

            if let r = remaining.range(of: timePattern, options: .regularExpression), r.lowerBound < earliestStart {
                earliestStart = r.lowerBound; earliestRange = r
                earliestColor = timerSelectionMode ? .accentOrange : .accentRed
            }

            if let r = remaining.range(of: tempPattern, options: .regularExpression), r.lowerBound < earliestStart {
                earliestStart = r.lowerBound; earliestRange = r
                earliestColor = .accentOrange
            }

            if let r = earliestRange, let color = earliestColor {
                let before = String(remaining[remaining.startIndex..<r.lowerBound])
                if !before.isEmpty { result = result + Text(before).foregroundColor(.textPrimary) }
                result = result + Text(String(remaining[r])).foregroundColor(color).fontWeight(.bold)
                remaining = String(remaining[r.upperBound...])
                continue
            }

            result = result + Text(String(remaining.first!)).foregroundColor(.textPrimary)
            remaining = String(remaining.dropFirst())
        }
        return result
    }

    // MARK: - Time Parsing

    private func extractTimeMatches(from text: String) -> [String] {
        var matches: [String] = []
        var remaining = text
        while let r = remaining.range(of: timePattern, options: .regularExpression) {
            matches.append(String(remaining[r]))
            remaining = String(remaining[r.upperBound...])
        }
        return matches
    }

    private func parseTimeToSeconds(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "一刻" || trimmed == "一刻钟" { return 15 * 60 }
        if trimmed == "一会" || trimmed == "一会儿" { return 5 * 60 }
        if trimmed == "半天" { return 12 * 3600 }
        if trimmed == "片刻" { return 2 * 60 }

        if let r = trimmed.range(of: #"(\d+)\s*(分钟|分|m(?!i))"#, options: .regularExpression) {
            let s = String(trimmed[r]); let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n * 60 }
        }
        if let r = trimmed.range(of: #"(\d+)\s*(小时|h)"#, options: .regularExpression) {
            let s = String(trimmed[r]); let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n * 3600 }
        }
        if let r = trimmed.range(of: #"(\d+)\s*(秒|s(?!\w))"#, options: .regularExpression) {
            let s = String(trimmed[r]); let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n }
        }
        if let r = trimmed.range(of: #"(\d+)\s*(min(?:ute)?s?|mins)"#, options: .regularExpression) {
            let s = String(trimmed[r]); let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n * 60 }
        }

        let chineseMap: [Character: Double] = ["一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10, "半": 0.5, "几": 5]
        if trimmed.range(of: #"[一二两三四五六七八九十半几]+\s*(分钟|小时|天)"#, options: .regularExpression) != nil {
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

    // MARK: - Live Activity Timer

    private func startTimer(match: String, stepNumber: Int) {
        guard let duration = parseTimeToSeconds(match) else { return }

        timerSelectionMode = false
        let recipeName = store.cookingRecipeName

        Task {
            // Start Live Activity
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

                // Tick every second
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

                // End with a brief "0:00" display + alarm sound
                await activity.end(using: CookingTimerAttributes.ContentState(
                    remainingSeconds: 0,
                    totalSeconds: Int(duration),
                    stepLabel: "Step \(stepNumber)",
                    recipeName: recipeName
                ), dismissalPolicy: .after(Date(timeIntervalSinceNow: 3)))

                // Play system alarm sound + vibration
                AudioServicesPlayAlertSound(1005)
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            } catch {
                // Live Activity not available (e.g. on iPad, simulator)
                print("Live Activity error: \(error)")
            }
        }
    }
}
