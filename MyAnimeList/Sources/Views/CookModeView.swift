import SwiftUI
import Combine

struct CookModeView: View {
    @Environment(RecipeStore.self) private var store
    @State private var timerSelectionMode = false
    @State private var selectedTimeText: String?
    @State private var timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timePattern: String {
        #"(?:\d+\s*(?:min(?:ute)?s?|mins|秒|hour(?:s)?|分钟|小时|分|天|周|个月|年))|(?:[一两二三四五六七八九十半几数]+\s*(?:分钟|小时|天|周|个月|年))|一刻|一会|一会儿|片刻|半天|半个月|半年|半日|数日"#
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cookingSteps.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Steps list
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(store.cookingSteps.enumerated()), id: \.element.id) { i, step in
                                    stepCard(i: i, step: step)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }

                        // Timers section
                        if !store.activeTimers.isEmpty {
                            timersSection
                        }
                    }
                    .background(Color.bgSecondary)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    (Text("\(store.remainingSteps)").font(.title2.weight(.bold)).foregroundColor(.black)
                    + Text(" steps").font(.bodyText.weight(.bold)).foregroundColor(.textSecondary))
                        .contentTransition(.numericText())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: handleAddTimer) {
                        Image(systemName: timerSelectionMode ? "timer.circle.fill" : "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(timerSelectionMode ? .accentOrange : .brandBlue)
                    }
                }
            }
            .onReceive(timerPublisher) { _ in tickTimers() }
            .onChange(of: store.cookingSteps.isEmpty) { _, empty in if empty { timerSelectionMode = false; selectedTimeText = nil } }
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
                // Step number
                ZStack {
                    Circle().fill(completed ? Color.accentGreen : Color.brandBlue).frame(width: 28, height: 28)
                    Text("\(i + 1)").font(.calloutText.weight(.bold)).foregroundColor(.white)
                }
                .padding(.top, 2)

                // Colored text
                cookingColoredText(step.description)
                    .font(.bodyText).lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .strikethrough(completed)
                    .opacity(completed ? 0.5 : 1)
                    .padding(.top, 2)

                // Checkbox
                Button(action: { store.toggleStep(step.id) }) {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(completed ? .accentGreen : .textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            // Tappable time pills (shown in timer selection mode)
            if timerSelectionMode && !completed && !timeMatches.isEmpty {
                HStack(spacing: 6) {
                    ForEach(timeMatches, id: \.self) { match in
                        Button(action: { onTimeTextTapped(match) }) {
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

    private func extractTimeMatches(from text: String) -> [String] {
        var matches: [String] = []
        var remaining = text
        while let r = remaining.range(of: timePattern, options: .regularExpression) {
            matches.append(String(remaining[r]))
            remaining = String(remaining[r.upperBound...])
        }
        return matches
    }

    // MARK: - Colored Text (matching RecipeDetailView)

    private func cookingColoredText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text
        let timePat = timePattern
        let tempPattern = #"\d+\s*(°[FC]|度)"#

        while !remaining.isEmpty {
            var earliestStart = remaining.endIndex
            var earliestRange: Range<String.Index>?
            var earliestColor: Color?
            var isTime = false

            // Time → red (or orange when in timer selection mode)
            if let r = remaining.range(of: timePat, options: .regularExpression), r.lowerBound < earliestStart {
                earliestStart = r.lowerBound; earliestRange = r
                earliestColor = timerSelectionMode ? .accentOrange : .accentRed
                isTime = true
            }

            // Temperature → orange
            if let r = remaining.range(of: tempPattern, options: .regularExpression), r.lowerBound < earliestStart {
                earliestStart = r.lowerBound; earliestRange = r
                earliestColor = .accentOrange
                isTime = false
            }

            if let r = earliestRange, let color = earliestColor {
                let before = String(remaining[remaining.startIndex..<r.lowerBound])
                if !before.isEmpty { result = result + Text(before).foregroundColor(.black) }

                let matched = String(remaining[r])
                if isTime && timerSelectionMode {
                    // In timer selection mode: time texts are tappable
                    result = result + Text(matched).foregroundColor(color).fontWeight(.bold)
                        // We handle tap via overlay on the entire step card
                } else {
                    result = result + Text(matched).foregroundColor(color).fontWeight(.bold)
                }
                remaining = String(remaining[r.upperBound...])
                continue
            }

            result = result + Text(String(remaining.first!)).foregroundColor(.black)
            remaining = String(remaining.dropFirst())
        }
        return result
    }

    // MARK: - Timer Logic

    private func handleAddTimer() {
        if timerSelectionMode {
            // Exit timer selection mode without creating timer
            timerSelectionMode = false
            selectedTimeText = nil
        } else if let text = selectedTimeText, let duration = parseTimeToSeconds(text) {
            // Create timer from selected time text
            store.addTimer(label: text, duration: duration)
            selectedTimeText = nil
        } else {
            // Enter timer selection mode
            timerSelectionMode = true
        }
    }

    private func onTimeTextTapped(_ text: String) {
        if timerSelectionMode, let duration = parseTimeToSeconds(text) {
            store.addTimer(label: text, duration: duration)
            timerSelectionMode = false
        } else if let duration = parseTimeToSeconds(text) {
            selectedTimeText = text
        }
    }

    private func parseTimeToSeconds(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // Handle "一刻" = 15 min
        if trimmed == "一刻" || trimmed == "一刻钟" { return 15 * 60 }
        // Handle "一会" / "一会儿" = 5 min
        if trimmed == "一会" || trimmed == "一会儿" { return 5 * 60 }
        // Handle "半天" = 12 hours
        if trimmed == "半天" { return 12 * 3600 }
        // Handle "片刻" = 2 min
        if trimmed == "片刻" { return 2 * 60 }

        // Parse numeric patterns
        if let r = trimmed.range(of: #"(\d+)\s*(分钟|分|m(?!i))"#, options: .regularExpression) {
            let s = String(trimmed[r])
            let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n * 60 }
        }
        if let r = trimmed.range(of: #"(\d+)\s*(小时|h)"#, options: .regularExpression) {
            let s = String(trimmed[r])
            let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n * 3600 }
        }
        if let r = trimmed.range(of: #"(\d+)\s*(秒|s(?!\w))"#, options: .regularExpression) {
            let s = String(trimmed[r])
            let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n }
        }
        if let r = trimmed.range(of: #"(\d+)\s*(天)"#, options: .regularExpression) {
            let s = String(trimmed[r])
            let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n * 86400 }
        }
        if let r = trimmed.range(of: #"(\d+)\s*(min(?:ute)?s?|mins)"#, options: .regularExpression) {
            let s = String(trimmed[r])
            let digits = s.prefix(while: \.isNumber)
            if let n = Double(digits) { return n * 60 }
        }

        // Chinese digits + unit
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

    private func tickTimers() {
        var updated = store.activeTimers
        for i in updated.indices where updated[i].isRunning && updated[i].remaining > 0 {
            updated[i].remaining -= 1
            if updated[i].remaining <= 0 {
                updated[i].remaining = 0
                updated[i].isRunning = false
            }
        }
        store.activeTimers = updated
        // Remove completed timers
        store.activeTimers.removeAll { $0.remaining <= 0 && !$0.isRunning }
    }

    // MARK: - Timers Section

    private var timersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timers").font(.captionText).foregroundColor(.textSecondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.activeTimers) { timer in
                        timerCard(timer)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 80)
        }
        .padding(.bottom, 8)
    }

    private func timerCard(_ timer: CookingTimer) -> some View {
        VStack(spacing: 4) {
            Text(timer.displayTime)
                .font(.title2.weight(.bold))
                .foregroundColor(timer.remaining > 0 ? .brandBlue : .accentRed)
                .monospacedDigit()
            Text(timer.label)
                .font(.captionText).foregroundColor(.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Button(action: { store.removeTimer(timer.id) }) {
                Image(systemName: "xmark.circle.fill").font(.caption).foregroundColor(.textTertiary)
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
        .onTapGesture {
            // Toggle timer running state
            if let idx = store.activeTimers.firstIndex(where: { $0.id == timer.id }) {
                store.activeTimers[idx].isRunning.toggle()
            }
        }
    }
}
