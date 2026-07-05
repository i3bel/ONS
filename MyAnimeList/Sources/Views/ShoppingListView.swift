import SwiftUI

struct ShoppingListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var completed = Set<String>()
    @State private var showIngredientEditor = false
    @State private var ingredientEditorText = ""

    private let feedback = UIImpactFeedbackGenerator(style: .medium)

    private var leftCount: Int {
        let allIds = Set(store.shoppingItems.map(\.id))
        return max(0, store.shoppingItems.count - completed.intersection(allIds).count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.shoppingItems.isEmpty {
                    emptyState
                } else {
                    shoppingList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onChange(of: store.shoppingItems.isEmpty) { _, empty in
                if empty { completed.removeAll() }
            }
            .onChange(of: store.shoppingItems) { _, items in
                completed = completed.intersection(Set(items.map(\.id)))
            }
            .sheet(isPresented: $showIngredientEditor) {
                ingredientEditorSheet
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            (Text("\(leftCount)")
                .font(.title2.weight(.bold)).foregroundColor(.textPrimary)
            + Text(" Left")
                .font(.bodyText.weight(.bold)).foregroundColor(.textSecondary))
            .contentTransition(.numericText())
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: {
                ingredientEditorText = ""
                showIngredientEditor = true
            }) {
                Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundColor(.brandBlue)
            }
        }
    }

    // MARK: List

    private var shoppingList: some View {
        List {
            ForEach(store.shoppingItems) { item in
                ShoppingItemRow(
                    item: item,
                    isCompleted: completed.contains(item.id),
                    onToggle: { toggle(item.id) },
                    onDelete: { store.removeShoppingItem(item.id) }
                )
                .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .background(Color.pageBg)
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart").font(.system(size: 40)).foregroundColor(.textTertiary)
            Text("采购清单为空").font(.title3.weight(.semibold))
            Text("从食谱详情添加或点击 + 手动添加").font(.calloutText).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggle(_ id: String) {
        feedback.impactOccurred()
        withAnimation {
            if completed.contains(id) { completed.remove(id) } else { completed.insert(id) }
        }
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
            .navigationTitle("添加食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showIngredientEditor = false }
                        .font(.bodyText.weight(.medium)).foregroundColor(.brandBlue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: commitIngredient) {
                        Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundColor(.brandBlue)
                    }
                    .disabled(ingredientEditorText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    private func commitIngredient() {
        let text = ingredientEditorText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        store.addShoppingItem(Ingredient.parseChinese(text))
        ingredientEditorText = ""
    }
}

// MARK: - Shopping Item Row

private struct ShoppingItemRow: View {
    var item: Ingredient
    var isCompleted: Bool
    var onToggle: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundColor(isCompleted ? .accentGreen : .textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.bodyText)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .textSecondary : .textPrimary)

                ingredientSubtitle
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.accentRed)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .opacity(isCompleted ? 0.5 : 1)
    }

    private var ingredientSubtitle: some View {
        Text(item.amountWithUnit).font(.captionText.weight(.semibold)).foregroundColor(.brandBlue)
        + Text("  \(item.name)").font(.captionText).foregroundColor(.textTertiary)
            .strikethrough(isCompleted)
    }
}
