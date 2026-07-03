import SwiftUI
import PhotosUI

// MARK: - Recipe Detail / Editor

struct RecipeDetailView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var recipe: Recipe?

    @State private var name: String = ""
    @State private var defaultServings: Int = 1
    @State private var status: RecipeStatus = .neutral
    @State private var notes: String = ""
    @State private var ingredients: [Ingredient] = []
    @State private var steps: [CookingStep] = []
    @State private var thumbnailData: Data? = nil
    @State private var showActionSheet = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var photoSelection: PhotosPickerItem? = nil
    @State private var showIngredientEditor = false
    @State private var editingIngredient: Ingredient?

    private var isNewRecipe: Bool { recipe == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    servingsSection
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
                Task { if let data = try? await item.loadTransferable(type: Data.self) { thumbnailData = data } }
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

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                if let data = thumbnailData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(height: 200).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    RoundedRectangle(cornerRadius: 20).fill(.thinMaterial).frame(height: 200)
                        .overlay { Image(systemName: "camera").font(.title).foregroundStyle(.secondary) }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showActionSheet = true }
            .confirmationDialog("缩略图", isPresented: $showActionSheet) {
                Button("从相册选择") { photoSelection = nil; showPhotoPicker = true }
                Button("拍照") { showCamera = true }
                if thumbnailData != nil { Button("删除", role: .destructive) { thumbnailData = nil } }
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
                Label("份数", systemImage: "person.2").font(.headline)
                Spacer()
                Stepper("\(defaultServings) 人份", value: $defaultServings, in: 1...20).labelsHidden()
                Text("\(defaultServings) 人份").font(.body.monospacedDigit().weight(.medium)).frame(width: 60, alignment: .trailing)
            }
        }
    }

    private var statusSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("状态", systemImage: "tag").font(.headline)
                Picker("状态", selection: $status) {
                    ForEach(RecipeStatus.allCases, id: \.self) { s in
                        Label(s.rawValue, systemImage: s.systemImage).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var ingredientsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("食材", systemImage: "carrot").font(.headline)
                    Spacer()
                    Button("添加") {
                        editingIngredient = Ingredient(id: UUID().uuidString, name: "", amount: 1, unit: "克", category: .other)
                        showIngredientEditor = true
                    }
                    .font(.subheadline.weight(.semibold))
                }
                if ingredients.isEmpty {
                    Text("还没有食材，点击添加").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                ForEach($ingredients) { $ing in
                    HStack(spacing: 8) {
                        Image(systemName: ing.category.systemImage).foregroundStyle(.secondary).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ing.name).font(.subheadline.weight(.medium))
                            Text(ing.displayAmount + " · " + ing.category.rawValue).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: { editingIngredient = ing; showIngredientEditor = true }) {
                            Image(systemName: "pencil").font(.caption)
                        }.buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { ingredients.removeAll { $0.id == ing.id } } label: { Image(systemName: "trash") }
                    }
                }
            }
        }
        .sheet(isPresented: $showIngredientEditor) {
            if let ing = editingIngredient {
                IngredientEditorView(ingredient: ing) { updated in
                    if let idx = ingredients.firstIndex(where: { $0.id == updated.id }) { ingredients[idx] = updated }
                    else { ingredients.append(updated) }
                    editingIngredient = nil
                } onCancel: { editingIngredient = nil }
            }
        }
    }

    private var stepsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("步骤", systemImage: "list.number").font(.headline)
                    Spacer()
                    Button("添加步骤") {
                        steps.append(CookingStep(id: UUID().uuidString, order: (steps.map(\.order).max() ?? 0) + 1, description: ""))
                    }
                    .font(.subheadline.weight(.semibold))
                }
                if steps.isEmpty {
                    Text("点击添加步骤开始编写").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
                    StepEditCard(index: idx, step: Binding(
                        get: { steps[idx] },
                        set: { steps[idx] = $0 }
                    ), onDelete: { steps.remove(at: idx) })
                }
            }
        }
    }

    private var notesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("备注", systemImage: "text.alignleft").font(.headline)
                TextEditor(text: $notes).font(.subheadline).scrollContentBackground(.hidden).frame(minHeight: 80)
            }
        }
    }

    // MARK: - Helpers

    private func loadRecipe() {
        guard let recipe else { return }
        name = recipe.name
        defaultServings = recipe.defaultServings
        status = recipe.status
        notes = recipe.notes
        ingredients = recipe.ingredients
        steps = recipe.steps
        if let fn = recipe.thumbnailFilename, let url = store.thumbnailURL(for: recipe), let d = try? Data(contentsOf: url) {
            thumbnailData = d
        }
    }

    private func saveAndDismiss() {
        let rid = recipe?.id ?? UUID().uuidString
        var thumbFn = recipe?.thumbnailFilename
        if let data = thumbnailData { thumbFn = store.saveThumbnail(data: data, for: rid) }
        else { thumbFn = nil }
        let updated = Recipe(
            id: rid,
            name: name,
            thumbnailFilename: thumbFn,
            defaultServings: max(1, defaultServings),
            status: status,
            notes: notes,
            ingredients: ingredients.map { Ingredient(id: $0.id, name: $0.name, amount: max(0, $0.amount), unit: $0.unit, category: $0.category, isPrepared: $0.isPrepared) },
            steps: steps.enumerated().map { i, s in CookingStep(id: s.id, order: i + 1, description: s.description, duration: s.duration) },
            createdAt: recipe?.createdAt ?? .now
        )
        if isNewRecipe { store.addRecipe(updated) }
        else { store.updateRecipe(updated) }
        dismiss()
    }
}

// MARK: - Step Edit Card

private struct StepEditCard: View {
    var index: Int
    @Binding var step: CookingStep
    var onDelete: () -> Void

    @State private var text: String = ""
    @State private var showTimePicker = false
    @State private var durationMinutes: Int = 0

    private let cookingVerbs = ["煮", "炖", "烤", "煎", "炸", "蒸", "炒", "焖", "煲", "焯", "熬"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(step.order)")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.secondary.opacity(0.1)))
                Spacer()
                if step.hasTimer {
                    Label(step.durationDisplay, systemImage: "timer").font(.caption.weight(.medium)).foregroundStyle(.orange)
                }
                Button(action: onDelete) { Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary) }
            }
            TextField("描述", text: $text, axis: .vertical)
                .font(.subheadline).lineLimit(2...6)
                .onChange(of: text) { _, new in
                    step.description = new
                    for verb in cookingVerbs where new.contains(verb) {
                        durationMinutes = Int(step.duration ?? 0) / 60
                        showTimePicker = true
                        break
                    }
                }
            Button(step.hasTimer ? "调整时间" : "添加计时") {
                durationMinutes = Int(step.duration ?? 0) / 60
                showTimePicker = true
            }
            .font(.caption).foregroundStyle(step.hasTimer ? .orange : .secondary)
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .onAppear { text = step.description }
        .sheet(isPresented: $showTimePicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("设置烹饪时间").font(.headline)
                    Picker("分钟", selection: $durationMinutes) {
                        ForEach(0...180, id: \.self) { m in Text("\(m) 分钟").tag(m) }
                    }
                    .pickerStyle(.wheel)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("确定") {
                            step.duration = durationMinutes > 0 ? TimeInterval(durationMinutes * 60) : nil
                            showTimePicker = false
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { showTimePicker = false }
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
                        TextField("用量", value: $amount, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    Picker("单位", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("分类", selection: $category) {
                        ForEach(IngredientCategory.allCases, id: \.self) { Label($0.rawValue, systemImage: $0.systemImage).tag($0) }
                    }
                }
            }
            .navigationTitle("食材").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { onSave(Ingredient(id: ingredient.id, name: name, amount: amount, unit: unit, category: category)); dismiss() }
                    .disabled(name.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
            }
            .onAppear { name = ingredient.name; amount = ingredient.amount; unit = ingredient.unit; category = ingredient.category }
        }
    }
}

// MARK: - Glass Card

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1) }
    }
}
