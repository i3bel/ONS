import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Recipe Editor

struct RecipeEditView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existingRecipe: Recipe?

    @State private var name = ""
    @State private var servings = 2
    @State private var prepH = 0
    @State private var prepM = 0
    @State private var cookH = 0
    @State private var cookM = 0
    @State private var ingredients: [Ingredient] = []
    @State private var steps: [CookingStep] = []
    @State private var tags: [String] = []
    @State private var photoData: Data? = nil
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showFilePicker = false
    @State private var showAddPhotoMenu = false
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var newIngredientText = ""

    // Ingredient editor sheet
    @State private var showIngredientEditor = false
    @State private var editingIngredientIndex: Int?
    @State private var ingredientEditorText = ""

    // Drag reorder
    @State private var draggedIngredient: Ingredient?
    @State private var draggedStep: CookingStep?
    @State private var draggedTag: String?

    // Focus management for new rows
    @FocusState private var focusedStepId: String?
    @FocusState private var focusedTagIndex: Int?

    // Picker wheels
    @State private var showServingsPicker = false
    @State private var showPrepPicker = false
    @State private var showCookPicker = false

    private var isNew: Bool { existingRecipe == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameField
                    infoSection
                    ingredientsSection
                    stepsSection
                    tagsSection
                    photosSection
                }
                .padding(.vertical)
            }
            .background(Color.pageBg)
            .navigationTitle(isNew ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Update") { save() }
                        .font(.bodyText.weight(.semibold)).foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(name.isEmpty ? Color.disabledBg : Color.accentRed).clipShape(Capsule())
                        .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: loadExisting)
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                Task { if let d = try? await item?.loadTransferable(type: Data.self) { photoData = d } }
            }
            .sheet(isPresented: $showCamera) {
                UIImagePicker(source: .camera) { img in photoData = img.jpegData(compressionQuality: 0.8); showCamera = false }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) { photoData = data }
                case .failure:
                    break
                }
            }
            .sheet(isPresented: $showServingsPicker) {
                NumberPickerView(title: "Servings", value: $servings, range: 1...30)
            }
            .sheet(isPresented: $showPrepPicker) {
                TimePickerView(title: "Prep Time", hours: $prepH, minutes: $prepM)
            }
            .sheet(isPresented: $showCookPicker) {
                TimePickerView(title: "Cook Time", hours: $cookH, minutes: $cookM)
            }
            .sheet(isPresented: $showIngredientEditor) {
                ingredientEditorSheet
            }
        }
    }

    // MARK: Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name").font(.captionText).foregroundColor(.textSecondary)
            TextField("Recipe Name", text: $name)
                .font(.title2.weight(.semibold)).textFieldStyle(.plain)
                .padding(16).background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Info (left-right aligned + picker wheels)

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Info").font(.captionText).foregroundColor(.textSecondary)
            VStack(spacing: 0) {
                // Servings
                HStack {
                    Text("Servings").font(.bodyText).foregroundColor(.textPrimary)
                    Spacer()
                    Button(action: { showServingsPicker = true }) {
                        Text("\(servings)").font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
                        Image(systemName: "chevron.down").font(.caption).foregroundColor(.brandBlue)
                    }
                }
                .padding(16)
                Divider().padding(.leading, 16)

                // Prep
                HStack {
                    Text("Prep").font(.bodyText).foregroundColor(.textPrimary)
                    Spacer()
                    Button(action: { showPrepPicker = true }) {
                        Text("\(prepH)h \(prepM)m").font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
                        Image(systemName: "chevron.down").font(.caption).foregroundColor(.brandBlue)
                    }
                }
                .padding(16)
                Divider().padding(.leading, 16)

                // Cook
                HStack {
                    Text("Cook").font(.bodyText).foregroundColor(.textPrimary)
                    Spacer()
                    Button(action: { showCookPicker = true }) {
                        Text("\(cookH)h \(cookM)m").font(.bodyText.weight(.semibold)).foregroundColor(.brandBlue)
                        Image(systemName: "chevron.down").font(.caption).foregroundColor(.brandBlue)
                    }
                }
                .padding(16)
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Ingredients").font(.captionText).foregroundColor(.textSecondary)
                Spacer()
                Text("\(ingredients.count)").font(.caption).foregroundColor(.textTertiary)
            }

            // Rounded rect container
            VStack(spacing: 0) {
                if !ingredients.isEmpty {
                    ForEach(Array(ingredients.enumerated()), id: \.element.id) { i, ing in
                        ingredientRow(i: i, ing: ing)
                            .onDrag {
                                draggedIngredient = ing
                                return NSItemProvider(object: ing.id as NSString)
                            }
                            .onDrop(of: [.text], delegate: IngredientDropDelegate(
                                targetId: ing.id,
                                ingredients: $ingredients,
                                draggedIngredient: $draggedIngredient
                            ))
                        if i < ingredients.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }

                // Add ingredient button at the bottom inside the rounded rect
                Button(action: {
                    editingIngredientIndex = nil
                    ingredientEditorText = ""
                    showIngredientEditor = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.brandBlue)
                        Text("Add Ingredient").font(.bodyText.weight(.medium)).foregroundColor(.brandBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.brandBlueLight, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(12)
                .buttonStyle(.plain)
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
    }

    private func ingredientRow(i: Int, ing: Ingredient) -> some View {
        HStack(spacing: 8) {
            // Delete button
            Button(action: { ingredients.remove(at: i) }) {
                Image(systemName: "minus.circle.fill").font(.title3).foregroundColor(.accentRed)
            }
            .buttonStyle(.plain)

            // Tappable text → opens editor
            Text(ing.displayString)
                .font(.bodyText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    ingredientEditorText = "\(ing.amount) \(ing.unit) \(ing.name)"
                    editingIngredientIndex = i
                    showIngredientEditor = true
                }

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.title3).foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Method").font(.captionText).foregroundColor(.textSecondary)
                Spacer()
                Text("\(steps.count)").font(.caption).foregroundColor(.textTertiary)
            }

            // Rounded rect container
            VStack(spacing: 0) {
                if !steps.isEmpty {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                        stepRow(i: i, step: step)
                            .onDrag {
                                draggedStep = step
                                return NSItemProvider(object: step.id as NSString)
                            }
                            .onDrop(of: [.text], delegate: StepDropDelegate(
                                targetId: step.id,
                                steps: $steps,
                                draggedStep: $draggedStep
                            ))
                        if i < steps.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }

                // Add step button at the bottom inside the rounded rect
                Button(action: {
                    let newStep = CookingStep(order: steps.count + 1, description: "")
                    steps.append(newStep)
                    focusedStepId = newStep.id
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.brandBlue)
                        Text("Add Step").font(.bodyText.weight(.medium)).foregroundColor(.brandBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.brandBlueLight, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(12)
                .buttonStyle(.plain)
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
    }

    private func stepRow(i: Int, step: CookingStep) -> some View {
        HStack(spacing: 8) {
            // Delete button
            Button(action: { steps.remove(at: i) }) {
                Image(systemName: "minus.circle.fill").font(.title3).foregroundColor(.accentRed)
            }
            .buttonStyle(.plain)

            // Step number
            ZStack {
                Circle().fill(Color.brandBlue).frame(width: 22, height: 22)
                Text("\(i + 1)").font(.caption.weight(.bold)).foregroundColor(.white)
            }

            // Inline editable text field (multi-line)
            TextField("输入步骤内容", text: $steps[i].description, axis: .vertical)
                .font(.bodyText)
                .lineLimit(1...10)
                .focused($focusedStepId, equals: step.id)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.title3).foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.captionText).foregroundColor(.textSecondary)

            // Rounded rect container
            VStack(spacing: 0) {
                if !tags.isEmpty {
                    ForEach(tags.indices, id: \.self) { i in
                        tagRow(i: i)
                            .onDrag {
                                draggedTag = tags[i]
                                return NSItemProvider(object: tags[i] as NSString)
                            }
                            .onDrop(of: [.text], delegate: TagDropDelegate(
                                targetId: tags[i],
                                tags: $tags,
                                draggedTag: $draggedTag
                            ))
                        if i < tags.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }

                // Add tag button at the bottom inside the rounded rect
                Button(action: {
                    tags.append("")
                    focusedTagIndex = tags.count - 1
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.brandBlue)
                        Text("Add Tag").font(.bodyText.weight(.medium)).foregroundColor(.brandBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.brandBlueLight, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(12)
                .buttonStyle(.plain)
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
    }

    private func tagRow(i: Int) -> some View {
        HStack(spacing: 8) {
            // Delete button
            Button(action: { tags.remove(at: i) }) {
                Image(systemName: "minus.circle.fill").font(.title3).foregroundColor(.accentRed)
            }
            .buttonStyle(.plain)

            // # prefix
            Text("#").font(.bodyText).foregroundColor(.tagText)

            // Inline editable text field
            TextField("输入标签", text: $tags[i])
                .font(.bodyText)
                .foregroundColor(.tagText)
                .focused($focusedTagIndex, equals: i)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.title3).foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos").font(.captionText).foregroundColor(.textSecondary)

            // Rounded rect container
            VStack(spacing: 0) {
                // Image preview if exists
                if let data = photoData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill().frame(height: 160).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(12)
                }

                // Add Photo button
                Button(action: { showAddPhotoMenu = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.brandBlue)
                        Text("Add Photo").font(.bodyText.weight(.medium)).foregroundColor(.brandBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.brandBlueLight, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 12)
                .padding(.top, photoData != nil ? 0 : 12)
                .padding(.bottom, photoData != nil ? 8 : 6)
                .buttonStyle(.plain)
                .confirmationDialog("Add Photo", isPresented: $showAddPhotoMenu) {
                    Button("Photo Library") { photoItem = nil; showPhotoPicker = true }
                    Button("Camera") { showCamera = true }
                    Button("Files") { showFilePicker = true }
                    Button("Cancel", role: .cancel) {}
                }

                // Delete Photo button (only when photo exists)
                if photoData != nil {
                    Button(action: { photoData = nil }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.circle.fill").font(.title3).foregroundColor(.accentRed)
                            Text("Delete Photo").font(.bodyText.weight(.medium)).foregroundColor(.accentRed)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.accentRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .buttonStyle(.plain)
                }
            }
            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Save

    private func save() {
        let rid = existingRecipe?.id ?? UUID().uuidString
        var photoFn = existingRecipe?.photoFilename
        if let d = photoData { photoFn = store.savePhoto(data: d, for: rid) }
        let r = Recipe(
            id: rid, name: name, servings: max(1, servings),
            prepTime: TimeInterval(prepH * 3600 + prepM * 60), cookTime: TimeInterval(cookH * 3600 + cookM * 60),
            ingredients: ingredients, steps: steps.enumerated().map { i, s in CookingStep(id: s.id, order: i + 1, description: s.description) },
            photoFilename: photoFn, tags: tags, createdAt: existingRecipe?.createdAt ?? .now
        )
        if isNew { store.add(r) } else { store.update(r) }
        dismiss()
    }

    private func loadExisting() {
        guard let r = existingRecipe else { return }
        name = r.name; servings = r.servings
        let p = Int(r.prepTime); prepH = p / 3600; prepM = (p % 3600) / 60
        let c = Int(r.cookTime); cookH = c / 3600; cookM = (c % 3600) / 60
        ingredients = r.ingredients; steps = r.steps; tags = r.tags
        if let fn = r.photoFilename, let url = store.photoURL(for: r), let d = try? Data(contentsOf: url) { photoData = d }
    }

    // MARK: Ingredient Editor Sheet

    private var ingredientEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("例如：一勺糖", text: $ingredientEditorText)
                    .font(.bodyText)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
                    .padding(20)
                Spacer()
            }
            .background(Color.pageBg)
            .navigationTitle(editingIngredientIndex != nil ? "Edit Ingredient" : "Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showIngredientEditor = false }
                        .font(.bodyText.weight(.medium)).foregroundColor(.brandBlue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: commitIngredientEditor) {
                        Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundColor(.brandBlue)
                    }
                    .disabled(ingredientEditorText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    private func commitIngredientEditor() {
        let text = ingredientEditorText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let parsed = Ingredient.parseChinese(text)
        if let idx = editingIngredientIndex, idx < ingredients.count {
            ingredients[idx] = parsed
            showIngredientEditor = false
            editingIngredientIndex = nil
        } else {
            ingredients.append(parsed)
            ingredientEditorText = ""
        }
    }

    // MARK: Step Editor Sheet

}

// MARK: - Drag Reorder Delegates

private struct IngredientDropDelegate: DropDelegate {
    let targetId: String
    @Binding var ingredients: [Ingredient]
    @Binding var draggedIngredient: Ingredient?

    func dropEntered(info: DropInfo) {
        guard let draggedIngredient,
              draggedIngredient.id != targetId,
              let fromIdx = ingredients.firstIndex(where: { $0.id == draggedIngredient.id }),
              let toIdx = ingredients.firstIndex(where: { $0.id == targetId }) else { return }
        withAnimation(.interactiveSpring) {
            ingredients.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedIngredient = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct StepDropDelegate: DropDelegate {
    let targetId: String
    @Binding var steps: [CookingStep]
    @Binding var draggedStep: CookingStep?

    func dropEntered(info: DropInfo) {
        guard let draggedStep,
              draggedStep.id != targetId,
              let fromIdx = steps.firstIndex(where: { $0.id == draggedStep.id }),
              let toIdx = steps.firstIndex(where: { $0.id == targetId }) else { return }
        withAnimation(.interactiveSpring) {
            steps.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedStep = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct TagDropDelegate: DropDelegate {
    let targetId: String
    @Binding var tags: [String]
    @Binding var draggedTag: String?

    func dropEntered(info: DropInfo) {
        guard let draggedTag,
              draggedTag != targetId,
              let fromIdx = tags.firstIndex(of: draggedTag),
              let toIdx = tags.firstIndex(of: targetId),
              tags.indices.contains(fromIdx), tags.indices.contains(toIdx) else { return }
        withAnimation(.interactiveSpring) {
            tags.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTag = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Number Picker Wheel

private struct NumberPickerView: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Picker(title, selection: $value) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.height(250)])
    }
}

// MARK: - Time Picker Wheel (hours + minutes)

private struct TimePickerView: View {
    var title: String
    @Binding var hours: Int
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("h", selection: $hours) { ForEach(0...23, id: \.self) { Text("\($0) h").tag($0) } }.pickerStyle(.wheel)
                Picker("m", selection: $minutes) { ForEach(0...59, id: \.self) { Text("\($0) m").tag($0) } }.pickerStyle(.wheel)
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.height(250)])
    }
}

