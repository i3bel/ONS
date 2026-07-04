import SwiftUI
import PhotosUI

// MARK: - Recipe Editor

struct RecipeEditView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existingRecipe: Recipe?

    @State private var name = ""
    @State private var servings = 2
    @State private var prepMin = 0
    @State private var cookMin = 0
    @State private var ingredients: [Ingredient] = []
    @State private var steps: [CookingStep] = []
    @State private var photoData: Data? = nil
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem? = nil

    // Inline ingredient input
    @State private var newIngredientText = ""
    @State private var newStepText = ""

    private var isNew: Bool { existingRecipe == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameField
                    infoFields
                    ingredientsSection
                    stepsSection
                    photosSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isNew ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.bodyText.weight(.medium)).foregroundColor(.black)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.cardBg).clipShape(Capsule())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Update") { save() }
                        .font(.bodyText.weight(.semibold))
                        .foregroundColor(name.isEmpty ? Color.disabledText : .white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(name.isEmpty ? Color.disabledBg : Color.brandBlue)
                        .clipShape(Capsule())
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
        }
    }

    // MARK: Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name").font(.headline).foregroundColor(Color.textSecondary)
            TextField("Recipe Name", text: $name)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Info (Servings, Prep, Cook)

    private var infoFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Info").font(.headline).foregroundColor(Color.textSecondary)
            VStack(spacing: 10) {
                HStack {
                    Text("Servings").frame(width: 80, alignment: .leading)
                    Stepper("\(servings) 人份", value: $servings, in: 1...20).labelsHidden()
                    Spacer()
                    Text("\(servings) 人份").font(.subheadline.monospacedDigit())
                }
                HStack {
                    Text("Prep").frame(width: 80, alignment: .leading)
                    Picker("", selection: $prepMin) { ForEach(0...180, id: \.self) { Text("\($0) 分钟").tag($0) } }
                }
                HStack {
                    Text("Cook").frame(width: 80, alignment: .leading)
                    Picker("", selection: $cookMin) { ForEach(0...300, id: \.self) { Text("\($0) 分钟").tag($0) } }
                }
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ingredients").font(.headline).foregroundColor(Color.textSecondary)
                Spacer()
                Text("\(ingredients.count)").font(.caption).foregroundColor(Color.textTertiary)
            }

            ForEach(Array(ingredients.enumerated()), id: \.element.id) { i, ing in
                HStack(spacing: 8) {
                    Button(action: { ingredients.remove(at: i) }) {
                        Image(systemName: "minus.circle.fill").foregroundColor(.red).font(.title3)
                    }
                    .buttonStyle(.plain)

                    Text(ing.displayString).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "line.3.horizontal").foregroundColor(Color.textTertiary).font(.caption)
                }
                .padding(10)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
            }

            // Add ingredient inline
            HStack(spacing: 8) {
                TextField("例如：一勺糖", text: $newIngredientText)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                Button("Add") {
                    guard !newIngredientText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let parsed = Ingredient.parseChinese(newIngredientText)
                    ingredients.append(parsed)
                    newIngredientText = ""
                }
                .font(.subheadline.weight(.semibold))
                .disabled(newIngredientText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
            .background(Color(.systemBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Method").font(.headline).foregroundColor(Color.textSecondary)
                Spacer()
                Text("\(steps.count)").font(.caption).foregroundColor(Color.textTertiary)
            }

            ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                HStack(alignment: .top, spacing: 8) {
                    Button(action: { steps.remove(at: i) }) {
                        Image(systemName: "minus.circle.fill").foregroundColor(.red).font(.title3)
                    }
                    .buttonStyle(.plain)

                    ZStack {
                        Circle().fill(Color.blue).frame(width: 22, height: 22)
                        Text("\(i + 1)").font(.caption.weight(.bold)).foregroundColor(.white)
                    }
                    .padding(.top, 2)

                    Text(step.description)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "line.3.horizontal").foregroundColor(Color.textTertiary).font(.caption).padding(.top, 4)
                }
                .padding(10)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
            }

            // Add step inline
            HStack(spacing: 8) {
                TextField("例如：热油下锅翻炒", text: $newStepText)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                Button("Add") {
                    guard !newStepText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    steps.append(CookingStep(order: steps.count + 1, description: newStepText))
                    newStepText = ""
                }
                .font(.subheadline.weight(.semibold))
                .disabled(newStepText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
            .background(Color(.systemBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos").font(.headline).foregroundColor(Color.textSecondary)

            if let data = photoData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(height: 180).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 12) {
                Button(action: { photoItem = nil; showPhotoPicker = true }) {
                    Label("Photo Library", systemImage: "photo.on.rectangle").font(.subheadline)
                }
                Button(action: { showCamera = true }) {
                    Label("Camera", systemImage: "camera").font(.subheadline)
                }
                if photoData != nil {
                    Button("Remove", role: .destructive) { photoData = nil }
                        .font(.subheadline)
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
            prepTime: TimeInterval(prepMin * 60), cookTime: TimeInterval(cookMin * 60),
            ingredients: ingredients, steps: steps.enumerated().map { i, s in CookingStep(id: s.id, order: i + 1, description: s.description) },
            photoFilename: photoFn, tags: existingRecipe?.tags ?? [],
            createdAt: existingRecipe?.createdAt ?? .now
        )
        if isNew { store.add(r) } else { store.update(r) }
        dismiss()
    }

    private func loadExisting() {
        guard let r = existingRecipe else { return }
        name = r.name; servings = r.servings
        prepMin = Int(r.prepTime / 60); cookMin = Int(r.cookTime / 60)
        ingredients = r.ingredients; steps = r.steps
        if let fn = r.photoFilename, let url = store.photoURL(for: r), let d = try? Data(contentsOf: url) { photoData = d }
    }
}
