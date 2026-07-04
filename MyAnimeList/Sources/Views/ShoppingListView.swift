import SwiftUI

struct ShoppingListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var completed = Set<String>()
    @State private var showIngredientEditor = false
    @State private var ingredientEditorText = ""

    private var leftCount: Int {
        max(0, store.shoppingItems.count - completed.intersection(Set(store.shoppingItems.map(\.id))).count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.shoppingItems.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.shoppingItems) { item in
                            HStack(spacing: 10) {
                                // Checkbox
                                Button(action: { toggle(item.id) }) {
                                    Image(systemName: completed.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3).foregroundColor(completed.contains(item.id) ? .accentGreen : .textSecondary)
                                }
                                .buttonStyle(.plain)

                                // Item info
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.bodyText)
                                        .strikethrough(completed.contains(item.id))
                                        .foregroundColor(completed.contains(item.id) ? .textSecondary : .textPrimary)

                                    ingredientSubtitle(item: item, completed: completed.contains(item.id))
                                }

                                Spacer()

                                // Delete
                                Button(action: { store.removeShoppingItem(item.id) }) {
                                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.accentRed)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(Color.cardBg, in: RoundedRectangle(cornerRadius: 12))
                            .opacity(completed.contains(item.id) ? 0.5 : 1)
                            .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.bgSecondary)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    (Text("\(leftCount)")
                        .font(.title2.weight(.bold)).foregroundColor(.textPrimary)
                    + Text(" left")
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart").font(.system(size: 40)).foregroundColor(.textTertiary)
            Text("采购清单为空").font(.title3.weight(.semibold))
            Text("从食谱详情添加或点击 + 手动添加").font(.calloutText).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggle(_ id: String) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        withAnimation { if completed.contains(id) { completed.remove(id) } else { completed.insert(id) } }
    }

    // MARK: - Ingredient Editor Sheet

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
        let parsed = Ingredient.parseChinese(text)
        store.addShoppingItem(parsed)
        ingredientEditorText = ""
    }

    private func ingredientSubtitle(item: Ingredient, completed: Bool) -> some View {
        let amt = Text(item.amountWithUnit).font(.captionText.weight(.semibold)).foregroundColor(.brandBlue)
        let name = Text("  \(item.name)").font(.captionText).foregroundColor(.textTertiary)
        return (amt + name).strikethrough(completed)
    }
}
