import Speech
import SwiftUI

// MARK: - Cook Mode (Crouton-style)

struct CookModeView: View {
    @Environment(RecipeStore.self) private var store
    @State private var selectedRecipe: Recipe? = nil
    @State private var currentStepIndex = 0
    @State private var servings: Int = 1
    @State private var phase: CookPhase = .select
    @State private var showCompletion = false

    enum CookPhase { case select, cooking }

    var body: some View {
        NavigationStack {
            switch phase {
            case .select:
                recipeSelectionView
            case .cooking:
                if let recipe = selectedRecipe {
                    StepCookingView(
                        recipe: recipe,
                        servings: servings,
                        currentStepIndex: $currentStepIndex,
                        onComplete: { showCompletion = true },
                        onBack: { phase = .select }
                    )
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .alert("全部完成！🎉", isPresented: $showCompletion) {
            Button("太棒了") {
                phase = .select
                selectedRecipe = nil
                currentStepIndex = 0
            }
        } message: {
            if let recipe = selectedRecipe {
                Text("\(recipe.name) 已完成全部 \(recipe.steps.count) 步！")
            }
        }
    }

    // MARK: - Recipe Selection

    private var recipeSelectionView: some View {
        Group {
            if store.recipes.isEmpty {
                ContentUnavailableView("没有菜谱", systemImage: "book", description: Text("先在菜谱页添加菜谱"))
            } else {
                List {
                    Section {
                        Text("选择一个菜谱开始烹饪")
                            .font(.title2.weight(.bold))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(store.recipes) { recipe in
                        Button(action: {
                            selectedRecipe = recipe
                            servings = recipe.defaultServings
                            currentStepIndex = 0
                            withAnimation { phase = .cooking }
                        }) {
                            HStack(spacing: 12) {
                                if let url = store.thumbnailURL(for: recipe),
                                   let img = UIImage(contentsOfFile: url.path) {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14))
                                } else {
                                    RoundedRectangle(cornerRadius: 14).fill(.orange.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                        .overlay { Image(systemName: "fork.knife").foregroundStyle(.orange) }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.name).font(.headline)
                                    Text("\(recipe.ingredients.count) 种食材 · \(recipe.steps.count) 步").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("烹饪")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Step Cooking View (Crouton-style full screen)

private struct StepCookingView: View {
    var recipe: Recipe
    var servings: Int
    @Binding var currentStepIndex: Int
    var onComplete: () -> Void
    var onBack: () -> Void

    @State private var showIngredient = false
    @State private var dragOffset: CGFloat = 0

    // Voice recognition
    @State private var voiceManager = VoiceCommandManager()

    private var step: CookingStep {
        recipe.steps[currentStepIndex]
    }

    private var progress: Double {
        Double(currentStepIndex + 1) / Double(max(1, recipe.steps.count))
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [.black, .black.opacity(0.9), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()

                    // Servings
                    HStack(spacing: 4) {
                        Image(systemName: "person.2").font(.caption)
                        Text("\(servings)人份").font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.1), in: Capsule())

                    // Voice indicator
                    Button(action: { voiceManager.toggle() }) {
                        Image(systemName: voiceManager.isListening ? "waveform" : "waveform.slash")
                            .font(.subheadline)
                            .foregroundStyle(voiceManager.isListening ? .orange : .white.opacity(0.4))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Progress bar
                ProgressView(value: progress)
                    .tint(.orange)
                    .padding(.horizontal)
                    .padding(.top, 12)

                // Step counter
                Text("步骤 \(currentStepIndex + 1) / \(recipe.steps.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)

                Spacer()

                // Step card
                VStack(spacing: 16) {
                    // Description with highlighted ingredients
                    highlightedText(step.description)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 24)

                    // Show ingredient quantities
                    Button(action: { showIngredient.toggle() }) {
                        Label(
                            showIngredient ? "收起用量" : "查看食材用量",
                            systemImage: showIngredient ? "chevron.up" : "info.circle"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 24)

                    if showIngredient {
                        ingredientList
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Timer button
                    if step.hasTimer {
                        StepTimerButton(duration: step.duration ?? 0)
                            .padding(.horizontal, 24)
                    }
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 80
                            if value.translation.width < -threshold {
                                goToNext()
                            } else if value.translation.width > threshold {
                                goToPrevious()
                            }
                            withAnimation(.spring) { dragOffset = 0 }
                        }
                )

                Spacer()

                // Bottom tap zones + progress dots
                VStack(spacing: 16) {
                    // Tap hints
                    HStack(spacing: 0) {
                        Button(action: goToPrevious) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.caption)
                                Text("上一步").font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(currentStepIndex == 0)
                        .opacity(currentStepIndex == 0 ? 0.3 : 1)

                        Spacer()

                        Button(action: goToNext) {
                            HStack(spacing: 4) {
                                Text(currentStepIndex < recipe.steps.count - 1 ? "下一步" : "完成")
                                    .font(.caption.weight(.medium))
                                Image(systemName: currentStepIndex < recipe.steps.count - 1 ? "chevron.right" : "checkmark").font(.caption)
                            }
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<recipe.steps.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentStepIndex ? Color.orange : Color.white.opacity(0.2))
                                .frame(width: i == currentStepIndex ? 10 : 6, height: i == currentStepIndex ? 10 : 6)
                                .animation(.spring, value: currentStepIndex)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            voiceManager.onCommand = { command in
                handleVoiceCommand(command)
            }
        }
        .onDisappear {
            voiceManager.stop()
        }
        .onTapGesture { location in
            let midX = UIScreen.main.bounds.width / 2
            if location.x < midX { goToPrevious() }
            else { goToNext() }
        }
    }

    // MARK: - Navigation

    private func goToNext() {
        guard currentStepIndex < recipe.steps.count - 1 else { onComplete(); return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStepIndex += 1
            showIngredient = false
        }
    }

    private func goToPrevious() {
        guard currentStepIndex > 0 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStepIndex -= 1
            showIngredient = false
        }
    }

    // MARK: - Voice

    private func handleVoiceCommand(_ command: String) {
        let lower = command.lowercased()
        if lower.contains("下一步") || lower.contains("next") || lower.contains("继续") {
            goToNext()
        } else if lower.contains("上一步") || lower.contains("previous") || lower.contains("back") || lower.contains("返回") {
            goToPrevious()
        } else if lower.contains("开始") || lower.contains("start") || lower.contains("计时") || lower.contains("timer") {
            // Timer will auto-start via the button
        }
    }

    // MARK: - Highlighted Text

    private func highlightedText(_ text: String) -> Text {
        let ingredientNames = recipe.ingredients.map(\.name)
        var result = Text("")

        let words = text.split { $0.isWhitespace || $0.isPunctuation }.map(String.init)
        var remaining = text
        for word in words {
            if ingredientNames.contains(where: { $0.localizedCaseInsensitiveContains(word) || word.localizedCaseInsensitiveContains($0) }) {
                if let range = remaining.range(of: word, options: .caseInsensitive) {
                    let before = String(remaining[remaining.startIndex..<range.lowerBound])
                    if !before.isEmpty { result = result + Text(before) }
                    result = result + Text(word).foregroundStyle(.orange).bold()
                    remaining = String(remaining[range.upperBound...])
                }
            }
        }
        if !remaining.isEmpty { result = result + Text(remaining) }
        return result
    }

    private var ingredientList: some View {
        VStack(spacing: 8) {
            ForEach(recipe.ingredients) { ing in
                HStack(spacing: 10) {
                    Image(systemName: ing.category.systemImage)
                        .font(.caption).foregroundStyle(.orange.opacity(0.7))
                        .frame(width: 20)
                    Text(ing.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(ing.displayAmount)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 24)
    }
}

// MARK: - Step Timer Button

private struct StepTimerButton: View {
    var duration: TimeInterval
    @State private var state = TimerState()

    private var totalMinutes: Int { Int(duration / 60) }

    var body: some View {
        VStack(spacing: 8) {
            if state.timeRemaining > 0 || state.isRunning {
                Text(formattedTime)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.isRunning ? .orange : .green)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: state.timeRemaining)

                HStack(spacing: 12) {
                    if state.isRunning {
                        Button("暂停") { state.pause() }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Button("继续") { state.resume() }
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    Button("重置") { state.reset() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else if state.isDone {
                Label("时间到！", systemImage: "bell.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Button(action: { state.start(duration: duration) }) {
                    Label("\(totalMinutes)分钟计时", systemImage: "timer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .buttonBorderShape(.capsule)
            }
        }
        .sensoryFeedback(.success, trigger: state.isDone)
    }

    private var formattedTime: String {
        let total = Int(state.timeRemaining)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - Timer State (Observable class for Sendable-safe timer)

@Observable
final class TimerState: @unchecked Sendable {
    var timeRemaining: TimeInterval = 0
    var isRunning = false
    var isDone = false
    private var currentTimer: Timer?

    func start(duration: TimeInterval) {
        timeRemaining = duration
        isRunning = true
        isDone = false
        currentTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                t.invalidate()
                isRunning = false
                isDone = true
            }
        }
    }

    func pause() {
        isRunning = false
        currentTimer?.invalidate()
    }

    func resume() {
        isRunning = true
        currentTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                t.invalidate()
                isRunning = false
                isDone = true
            }
        }
    }

    func reset() {
        pause()
        timeRemaining = 0
        isDone = false
    }
}

// MARK: - Voice Command Manager

@Observable
final class VoiceCommandManager: @unchecked Sendable {
    var isListening = false
    var onCommand: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func toggle() {
        if isListening { stop() }
        else { start() }
    }

    func start() {
        guard !isListening else { return }
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                self.startListening()
            }
        }
    }

    func stop() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
    }

    private func startListening() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.onCommand?(text)
                } else {
                    // Check for command keywords in partial results
                    let lower = text.lowercased()
                    if lower.contains("下一步") || lower.contains("上一步") || lower.contains("next") || lower.contains("back") {
                        self.onCommand?(text)
                        self.recognitionTask?.cancel()
                        self.startListening()
                    }
                }
            }
            if error != nil {
                self.stop()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
    }
}
