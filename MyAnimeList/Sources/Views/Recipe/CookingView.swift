import SwiftUI
import Combine

// MARK: - Cooking View

struct CookingView: View {
    @Environment(RecipeStore.self) private var store
    @State private var selectedRecipe: Recipe? = nil
    @State private var servings: Int = 1
    @State private var currentStepIndex: Int = 0
    @State private var phase: CookingPhase = .select
    @State private var showCompletion = false

    enum CookingPhase {
        case select        // 选择菜谱
        case prepare       // 食材 checklist
        case cook          // 分步烹饪
    }

    var body: some View {
        NavigationStack {
            switch phase {
            case .select:
                recipeSelectionView
            case .prepare:
                prepareView
            case .cook:
                cookView
            }
        }
        .alert("烹饪完成！🎉", isPresented: $showCompletion) {
            Button("重新开始") { reset() }
            Button("完成") {
                reset()
                phase = .select
            }
        } message: {
            if let recipe = selectedRecipe {
                Text("\(recipe.name) 已完成全部 \(recipe.steps.count) 步！")
            }
        }
    }

    // MARK: - Select Recipe

    private var recipeSelectionView: some View {
        Group {
            if store.recipes.isEmpty {
                ContentUnavailableView(
                    "没有菜谱",
                    systemImage: "book",
                    description: Text("先在菜谱页添加菜谱")
                )
            } else {
                List {
                    Section {
                        Text("选择要制作的菜谱")
                            .font(.title2.weight(.bold))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(store.recipes) { recipe in
                        Button(action: {
                            selectedRecipe = recipe
                            servings = recipe.defaultServings
                            currentStepIndex = 0
                            phase = .prepare
                        }) {
                            HStack(spacing: 12) {
                                if let url = store.thumbnailURL(for: recipe),
                                   let uiImage = UIImage(contentsOfFile: url.path) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.orange.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                        .overlay { Image(systemName: "fork.knife").foregroundStyle(.orange) }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.name)
                                        .font(.headline)
                                    if !recipe.ingredients.isEmpty {
                                        Text("\(recipe.ingredients.count) 种食材 · \(recipe.steps.count) 步")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("制作")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Prepare (Ingredient Checklist)

    private var prepareView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text(selectedRecipe?.name ?? "")
                    .font(.title2.weight(.bold))

                HStack(spacing: 12) {
                    Label("\(servings) 人份", systemImage: "person.2")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Stepper("份数", value: $servings, in: 1...20)
                        .labelsHidden()
                }
            }
            .padding()
            .background(.thinMaterial)

            // Ingredient Checklist
            if let recipe = selectedRecipe {
                let scaled = recipe.scaledIngredients(for: servings)

                List {
                    Section {
                        Text("检查食材是否准备齐全")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(scaled) { ingredient in
                        HStack(spacing: 10) {
                            Button(action: {
                                togglePrepared(ingredient)
                            }) {
                                Image(systemName: ingredient.isPrepared ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(ingredient.isPrepared ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                    .font(.subheadline.weight(.medium))
                                    .strikethrough(ingredient.isPrepared)
                                Text("\(ingredient.displayAmount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .opacity(ingredient.isPrepared ? 0.6 : 1)

                            Spacer()

                            Image(systemName: ingredient.category.systemImage)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }

            // Bottom bar
            HStack(spacing: 16) {
                Button("返回选择", role: .cancel) {
                    phase = .select
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Button("开始烹饪") {
                    phase = .cook
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
            .padding()
            .background(.thinMaterial)
        }
    }

    // MARK: - Cook (Step-by-step)

    private var cookView: some View {
        VStack(spacing: 0) {
            // Progress header
            if let recipe = selectedRecipe {
                VStack(spacing: 8) {
                    HStack {
                        Text(recipe.name)
                            .font(.headline)
                        Spacer()
                        Text("\(currentStepIndex + 1) / \(recipe.steps.count)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: Double(currentStepIndex + 1), total: Double(recipe.steps.count))
                        .tint(.orange)
                }
                .padding()
                .background(.thinMaterial)

                // Step content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                                StepCookingCard(
                                    step: step,
                                    index: index,
                                    isActive: index == currentStepIndex,
                                    isCompleted: index < currentStepIndex,
                                    servings: servings,
                                    recipe: recipe
                                )
                                .id(step.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: currentStepIndex) { _, idx in
                        if idx < recipe.steps.count {
                            withAnimation {
                                proxy.scrollTo(recipe.steps[idx].id, anchor: .center)
                            }
                        }
                    }
                }

                // Bottom controls
                HStack(spacing: 16) {
                    if currentStepIndex > 0 {
                        Button("上一步") {
                            currentStepIndex -= 1
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    }

                    Spacer()

                    if currentStepIndex < recipe.steps.count - 1 {
                        Button("下一步") {
                            currentStepIndex += 1
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    } else {
                        Button("完成！") {
                            showCompletion = true
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(.green)
                    }
                }
                .padding()
                .background(.thinMaterial)
            }
        }
    }

    // MARK: - Helpers

    private func togglePrepared(_ ingredient: Ingredient) {
        guard let recipe = selectedRecipe,
              let recipeIdx = store.recipes.firstIndex(where: { $0.id == recipe.id }),
              let ingIdx = store.recipes[recipeIdx].ingredients.firstIndex(where: { $0.id == ingredient.id })
        else { return }
        store.recipes[recipeIdx].ingredients[ingIdx].isPrepared.toggle()
        store.save()
        // Refresh the scaled list
        if let updated = store.recipes.first(where: { $0.id == recipe.id }) {
            selectedRecipe = updated
        }
    }

    private func reset() {
        selectedRecipe = nil
        servings = 1
        currentStepIndex = 0
        showCompletion = false
    }
}

// MARK: - Step Cooking Card

private struct StepCookingCard: View {
    var step: CookingStep
    var index: Int
    var isActive: Bool
    var isCompleted: Bool
    var servings: Int
    var recipe: Recipe

    @State private var timeRemaining: TimeInterval = 0
    @State private var timerRunning = false
    @State private var timerDone = false
    @State private var timerCancellable: AnyCancellable? = nil
    @State private var showTimerComplete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step header
            HStack {
                ZStack {
                    Circle()
                        .fill(backgroundTint)
                        .frame(width: 32, height: 32)
                    Text("\(index + 1)")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                }

                Text("Step \(index + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if isCompleted {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Description
            Text(step.description)
                .font(.body)
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Timer
            if step.hasTimer {
                VStack(spacing: 8) {
                    if timerRunning || timeRemaining > 0 {
                        Text(formattedTime)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(timeRemaining > 0 ? .orange : .green)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: timeRemaining)

                        if timerRunning {
                            Button("暂停") { pauseTimer() }
                                .font(.subheadline)
                                .buttonStyle(.bordered)
                        } else if timeRemaining > 0 {
                            Button("继续") { resumeTimer() }
                                .font(.subheadline)
                                .buttonStyle(.borderedProminent)
                        }
                    }

                    if !timerRunning && timeRemaining == 0 && !timerDone {
                        Button(action: startTimer) {
                            Label("开始计时 \(step.durationDisplay)", systemImage: "timer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .buttonBorderShape(.capsule)
                    }

                    if timerDone {
                        Label("时间到！", systemImage: "bell.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding(.vertical, 4)
                    }
                }
            }

            // Ingredient scaling info
            if index == 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption2)
                    Text("\(recipe.defaultServings) 人份基准 · 当前 \(servings) 人份")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isActive ? Color.orange.opacity(0.08) : Color(.systemBackground).opacity(0.5))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isActive ? Color.orange.opacity(0.3) : Color.white.opacity(0.06), lineWidth: isActive ? 2 : 1)
        }
        .scaleEffect(isActive ? 1.02 : 1)
        .animation(.spring(response: 0.35), value: isActive)
        .alert("计时完成！", isPresented: $showTimerComplete) {
            Button("好的") { }
        } message: {
            Text("\(step.description)")
        }
        .sensoryFeedback(.success, trigger: timerDone)
    }

    private var backgroundTint: Color {
        if isCompleted { return .green }
        if isActive { return .orange }
        return .secondary.opacity(0.4)
    }

    private var formattedTime: String {
        let total = Int(timeRemaining)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimer() {
        guard let duration = step.duration, duration > 0 else { return }
        timeRemaining = duration
        timerRunning = true
        timerDone = false
        timerCancellable = Timer.publish(every: 1, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timerRunning = false
                    timerDone = true
                    showTimerComplete = true
                    timerCancellable?.cancel()
                }
            }
    }

    private func pauseTimer() {
        timerRunning = false
        timerCancellable?.cancel()
    }

    private func resumeTimer() {
        timerRunning = true
        timerCancellable = Timer.publish(every: 1, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timerRunning = false
                    timerDone = true
                    showTimerComplete = true
                    timerCancellable?.cancel()
                }
            }
    }
}
