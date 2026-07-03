import SwiftUI
import PhotosUI

// MARK: - Recipe Detail / Editor

struct RecipeDetailView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var recipe: Recipe?
    @State private var name: String = ""
    @State private var defaultServings: Int = 1
    @State private var prepTime: Int = 0
    @State private var cookTime: Int = 0
    @State private var status: RecipeStatus = .neutral
    @State private var notes: String = ""
    @State private var ingredients: [Ingredient] = []
    @State private var steps: [CookingStep] = []
    @State private var thumbnailData: Data? = nil
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var photoSelection: PhotosPickerItem? = nil
    @State private var showActionSheet = false
    @State private var showIngredientEditor = false
    @State private var editingIngredient: Ingredient?
    @State private var newStepText = ""

    private let cookingVerbs = ["煮", "炖", "烤", "煎", "炸", "蒸", "炒", "焖", "煲", "焯", "熬"]
    @State private var showTimePicker = false
    @State private var pendingStepIndex: Int? = nil
    @State private var pendingTime: Int = 0

    private var isNewRecipe: Bool { recipe == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    basicInfoSection
                    servingsSection
                    timeSection
                    statusSection
                    ingredientsSection
                    stepsSection
                    notesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isNewRecipe ? "新建菜谱" : "编辑菜谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear(perform: loadRecipe)
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoSelection, matching: .images)
            .onChange(of: photoSelection) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        thumbnailData = data
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                UIImagePicker(source: .camera) { image in
                    thumbnailData = image.jpegData(compressionQuality: 0.8)
                    showCamera = false
                }
            }
        }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        VStack(spacing: 16) {
            // Thumbnail
            ZStack {
                if let data = thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.thinMaterial)
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "camera")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showActionSheet = true }
            .confirmationDialog("设置菜谱缩略图", isPresented: $showActionSheet) {
                Button("从相册选择") {
                    photoSelection = nil
                    showPhotoPicker = true
                }
                Button("拍照") { showCamera = true }
                Button("取消", role: .cancel) {}
            }

            TextField("菜谱名称", text: $name)
                .font(.title2.weight(.bold))
                .textFieldStyle(.plain)
        }
    }

    private var servingsSection: some View {
        GlassCard {
            HStack {
                Label("份数", systemImage: "person.2")
                    .font(.headline)
                Spacer()
                Stepper("\(defaultServings) 人份", value: $defaultServings, in: 1...20)
                    .labelsHidden()
                Text("\(defaultServings) 人份")
                    .font(.body.monospacedDigit().weight(.medium))
                    .frame(width: 60, alignment: .trailing)
            }
            if !ingredients.isEmpty {
                Text("食材用量基于 \(defaultServings) 人份，制作时可缩放")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeSection: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Label("准备时间", systemImage: "clock")
                    Spacer()
                    Picker("", selection: $prepTime) {
                        Text("无").tag(0)
                        ForEach(1...120, id: \.self) { m in
                            Text("\(m) 分钟").tag(m)
                        }
                    }
                }
                HStack {
                    Label("烹饪时间", systemImage: "flame")
                    Spacer()
                    Picker("", selection: $cookTime) {
                        Text("无").tag(0)
                        ForEach(1...240, id: \.self) { m in
                            Text("\(m) 分钟").tag(m)
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("状态", systemImage: "tag")
                    .font(.headline)
                Picker("状态", selection: $status) {
                    ForEach(RecipeStatus.allCases, id: \.self) { s in
                        Label(s.rawValue, systemImage: s.systemImage).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("食材", systemImage: "carrot")
                        .font(.headline)
                    Spacer()
                    Button("添加") {
                        editingIngredient = Ingredient(id: UUID().uuidString, name: "", amount: 1, unit: "克", category: .other)
                        showIngredientEditor = true
                    }
                    .font(.subheadline.weight(.semibold))
                }

                if ingredients.isEmpty {
                    Text("还没有食材，点击添加")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach($ingredients) { $ingredient in
                        HStack(spacing: 8) {
                            Image(systemName: ingredient.category.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                    .font(.subheadline.weight(.medium))
                                Text("\(ingredient.displayAmount) · \(ingredient.category.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: { editingIngredient = ingredient; showIngredientEditor = true }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                ingredients.removeAll { $0.id == ingredient.id }
                            } label: { Image(systemName: "trash") }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showIngredientEditor) {
            if let ingredient = editingIngredient {
                IngredientEditorView(
                    ingredient: ingredient,
                    onSave: { updated in
                        if let idx = ingredients.firstIndex(where: { $0.id == updated.id }) {
                            ingredients[idx] = updated
                        } else {
                            ingredients.append(updated)
                        }
                        editingIngredient = nil
                    },
                    onCancel: { editingIngredient = nil }
                )
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("步骤", systemImage: "list.number")
                        .font(.headline)
                    Spacer()
                    Button("添加步骤") {
                        let newStep = CookingStep(
                            id: UUID().uuidString,
                            order: (steps.map(\.order).max() ?? 0) + 1,
                            description: ""
                        )
                        steps.append(newStep)
                    }
                    .font(.subheadline.weight(.semibold))
                }

                if steps.isEmpty {
                    Text("点击添加步骤开始编写")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    StepCard(
                        index: index,
                        step: step,
                        onDelete: { steps.removeAll { $0.id == step.id } },
                        onDescriptionChange: { newDesc in
                            steps[index].description = newDesc
                            checkForCookingVerb(newDesc, stepIndex: index)
                        },
                        onDurationChange: { newDuration in
                            steps[index].duration = newDuration
                        }
                    )
                }
            }
        }
        // Time Picker Sheet
        .sheet(isPresented: $showTimePicker) {
            timePickerSheet
        }
    }

    private var timePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("设置烹饪时间")
                    .font(.headline)

                HStack {
                    Picker("分钟", selection: $pendingTime) {
                        ForEach(0...180, id: \.self) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                    Text("分钟")
                        .font(.title3.weight(.medium))
                }

                Button("确定") {
                    if let idx = pendingStepIndex, idx < steps.count {
                        steps[idx].duration = TimeInterval(pendingTime * 60)
                    }
                    showTimePicker = false
                    pendingStepIndex = nil
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        showTimePicker = false
                        pendingStepIndex = nil
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    private func checkForCookingVerb(_ text: String, stepIndex: Int) {
        for verb in cookingVerbs {
            if text.contains(verb) {
                pendingStepIndex = stepIndex
                pendingTime = Int(steps[safe: stepIndex]?.duration ?? 0) / 60
                showTimePicker = true
                return
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("备注", systemImage: "text.alignleft")
                    .font(.headline)
                TextEditor(text: $notes)
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
            }
        }
    }

    // MARK: - Helpers

    private func loadRecipe() {
        guard let recipe else { return }
        name = recipe.name
        defaultServings = recipe.defaultServings
        prepTime = Int(recipe.prepTime / 60)
        cookTime = Int(recipe.cookTime / 60)
        status = recipe.status
        notes = recipe.notes
        ingredients = recipe.ingredients
        steps = recipe.steps
        if let filename = recipe.thumbnailFilename,
           let url = store.thumbnailURL(for: recipe),
           let data = try? Data(contentsOf: url) {
            thumbnailData = data
        }
    }

    private func saveAndDismiss() {
        let recipeID = recipe?.id ?? UUID().uuidString
        var thumbnailFilename = recipe?.thumbnailFilename
        if let data = thumbnailData {
            thumbnailFilename = store.saveThumbnail(data: data, for: recipeID)
        } else {
            thumbnailFilename = nil
        }

        let updated = Recipe(
            id: recipeID,
            name: name,
            thumbnailFilename: thumbnailFilename,
            defaultServings: max(1, defaultServings),
            prepTime: TimeInterval(prepTime * 60),
            cookTime: TimeInterval(cookTime * 60),
            status: status,
            notes: notes,
            ingredients: ingredients.map { ing in
                Ingredient(id: ing.id, name: ing.name, amount: max(0, ing.amount), unit: ing.unit, category: ing.category, isPrepared: ing.isPrepared)
            },
            steps: steps.enumerated().map { i, s in
                CookingStep(id: s.id, order: i + 1, description: s.description, duration: s.duration)
            },
            createdAt: recipe?.createdAt ?? .now
        )

        if isNewRecipe {
            store.addRecipe(updated)
        } else {
            store.updateRecipe(updated)
        }
        dismiss()
    }
}

// MARK: - Step Card

private struct StepCard: View {
    var index: Int
    var step: CookingStep
    var onDelete: () -> Void
    var onDescriptionChange: (String) -> Void
    var onDurationChange: (TimeInterval?) -> Void

    @State private var text: String = ""
    @State private var showDurationPicker = false
    @State private var durationMinutes: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(step.order)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.secondary.opacity(0.1)))

                Spacer()

                if step.hasTimer {
                    Label(step.durationDisplay, systemImage: "timer")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("描述", text: $text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...6)
                .onChange(of: text) { _, new in
                    onDescriptionChange(new)
                }

            if step.hasTimer {
                Button("调整时间") {
                    durationMinutes = Int(step.duration ?? 0) / 60
                    showDurationPicker = true
                }
                .font(.caption)
                .foregroundStyle(.orange)
            } else {
                Button("添加计时") {
                    durationMinutes = 0
                    showDurationPicker = true
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { text = step.description }
        .sheet(isPresented: $showDurationPicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("设置烹饪时间")
                        .font(.headline)
                    Picker("分钟", selection: $durationMinutes) {
                        ForEach(0...180, id: \.self) { m in
                            Text("\(m) 分钟").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("确定") {
                            if durationMinutes > 0 {
                                onDurationChange(TimeInterval(durationMinutes * 60))
                            } else {
                                onDurationChange(nil)
                            }
                            showDurationPicker = false
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { showDurationPicker = false }
                    }
                }
            }
            .presentationDetents([.height(280)])
        }
    }
}

// MARK: - Ingredient Editor

private struct IngredientEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var ingredient: Ingredient
    var onSave: (Ingredient) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var amount: Double = 1
    @State private var unit: String = "克"
    @State private var category: IngredientCategory = .other

    private let units = ["克", "毫升", "个", "勺", "碗", "根", "片", "只", "包", "盒", "束", "适量"]

    var body: some View {
        NavigationStack {
            Form {
                Section("食材信息") {
                    TextField("名称", text: $name)
                    HStack {
                        Text("用量")
                        Spacer()
                        TextField("用量", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Picker("单位", selection: $unit) {
                        ForEach(units, id: \.self) { u in
                            Text(u).tag(u)
                        }
                    }
                    Picker("分类", selection: $category) {
                        ForEach(IngredientCategory.allCases, id: \.self) { c in
                            Label(c.rawValue, systemImage: c.systemImage).tag(c)
                        }
                    }
                }
            }
            .navigationTitle("编辑食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let updated = Ingredient(
                            id: ingredient.id,
                            name: name,
                            amount: amount,
                            unit: unit,
                            category: category
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                name = ingredient.name
                amount = ingredient.amount
                unit = ingredient.unit
                category = ingredient.category
            }
        }
    }
}

// MARK: - Glass Card

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
