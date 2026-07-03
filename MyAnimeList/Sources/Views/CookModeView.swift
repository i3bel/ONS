import SwiftUI

struct CookModeView: View {
    @Environment(RecipeStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.recipes.isEmpty {
                ContentUnavailableView("还没有食谱", systemImage: "frying.pan", description: Text("先在食谱页添加食谱"))
            } else {
                List(store.recipes) { recipe in
                    Button(action: { /* start cooking */ }) {
                        HStack(spacing: 12) {
                            if let url = store.photoURL(for: recipe), let img = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12).fill(.orange.opacity(0.2)).frame(width: 60, height: 60)
                                    .overlay { Image(systemName: "fork.knife").foregroundStyle(.orange) }
                            }
                            Text(recipe.name).font(.headline)
                            Spacer()
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.orange)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .navigationTitle("烹饪").navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
