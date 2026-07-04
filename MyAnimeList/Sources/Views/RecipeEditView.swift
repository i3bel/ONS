import SwiftUI
import PhotosUI

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
    @State private var newTag = ""
    @State private var photoData: Data? = nil
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var newIngredientText = ""
    @State private var newStepText = ""

    // Ingredient editor sheet
    @State private var showIngredientEditor = false
    @State private var editingIngredientIndex: Int?
    @State private var ingredientEditorText = ""

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
                    Text("Servings").font(.bodyText).foregroundColor(.black)
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
                    Text("Prep").font(.bodyText).foregroundColor(.black)
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
                    Text("Cook").font(.bodyText).foregroundColor(.black)
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

            if !steps.isEmpty {
                List {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                        HStack(alignment: .top, spacing: 8) {
                            Button(action: { steps.remove(at: i) }) {
                                Image(systemName: "minus.circle.fill").font(.title3).foregroundColor(.accentRed)
                            }
                            .buttonStyle(.plain)
                            ZStack {
                                Circle().fill(Color.brandBlue).frame(width: 22, height: 22)
                                Text("\(i + 1)").font(.caption.weight(.bold)).foregroundColor(.white)
                            }
                            Text(step.description).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(4)
                    }
                    .onMove { from, to in steps.move(fromOffsets: from, toOffset: to) }
                    .onDelete { i in steps.remove(at: i.first!) }
                }
                .listStyle(.plain).frame(minHeight: CGFloat(steps.count * 50))
            }

            // Add step
            HStack(spacing: 8) {
                TextField("例如：热油下锅翻炒", text: $newStepText).font(.subheadline).textFieldStyle(.plain)
                Button("Add") {
                    guard !newStepText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    steps.append(CookingStep(order: steps.count + 1, description: newStepText))
                    newStepText = ""
                }
                .font(.subheadline.weight(.semibold)).foregroundColor(newStepText.trimmingCharacters(in: .whitespaces).isEmpty ? .textTertiary : .brandBlue)
                .disabled(newStepText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12).background(Color.cardBg.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.captionText).foregroundColor(.textSecondary)

            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags.indices, id: \.self) { i in
                        HStack(spacing: 4) {
                            Text("#\(tags[i])").font(.calloutText).foregroundColor(.tagText)
                            Button(action: { tags.remove(at: i) }) {
                                Image(systemName: "xmark").font(.caption2).foregroundColor(.tagText)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.tagBg).clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("添加标签", text: $newTag).font(.subheadline).textFieldStyle(.plain)
                Button("Add") {
                    let tag = newTag.trimmingCharacters(in: .whitespaces)
                    guard !tag.isEmpty else { return }
                    tags.append(tag); newTag = ""
                }
                .font(.subheadline.weight(.semibold)).foregroundColor(newTag.trimmingCharacters(in: .whitespaces).isEmpty ? .textTertiary : .brandBlue)
            }
            .padding(12).background(Color.cardBg, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos").font(.captionText).foregroundColor(.textSecondary)
            if let data = photoData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 160).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            HStack(spacing: 24) {
                Button(action: { photoItem = nil; showPhotoPicker = true }) {
                    Label("Photo Library", systemImage: "photo.on.rectangle").font(.subheadline).foregroundColor(.brandBlue)
                }
                Button(action: { showCamera = true }) {
                    Label("Camera", systemImage: "camera").font(.subheadline).foregroundColor(.brandBlue)
                }
                if photoData != nil {
                    Button("Remove", role: .destructive) { photoData = nil }.font(.subheadline)
                }
            }
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

// MARK: - Simple Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 300
        var y: CGFloat = 0, x: CGFloat = 0, rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            rowH = max(rowH, sz.height)
            x += sz.width + spacing
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowH = max(rowH, sz.height)
            x += sz.width + spacing
        }
    }
}
