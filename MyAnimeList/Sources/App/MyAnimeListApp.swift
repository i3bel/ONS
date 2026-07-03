//
//  MyAnimeListApp.swift
//  MyAnimeList
//
//  Created by Samuel He on 2024/12/8.
//

import DataProvider
import SwiftData
import SwiftUI

@main
<<<<<<< Updated upstream
struct MyAnimeListApp: App {
    @State var libraryStore: LibraryStore = .init(dataProvider: .default)
    @State var keyStorage: TMDbAPIKeyStorage = .init()
    @State var whatsNew: WhatsNewController = .init()
 
    @AppStorage(.preferredAnimeInfoLanguage) var preferredLanguage: Language = .english
    @AppStorage(.useCurrentLocaleForAnimeInfoLanguage) var followsSystemLanguage: Bool =
        Language.followsSystemPreference()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let key = keyStorage.key, !key.isEmpty {
                    LibraryView()
                        .onAppear {
                            libraryStore.language = followsSystemLanguage ? .current : preferredLanguage
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 1)))
                } else {
                    TMDbAPIOnboardingView()
                        .transition(.opacity.animation(.easeInOut(duration: 1)))
                }
            }
            .environment(libraryStore)
            .environment(keyStorage)
            .environment(whatsNew)
            .environment(\.dataHandler, DataProvider.default.dataHandler)
            .sheet(item: presentedWhatsNewEntry) { entry in
                NavigationStack {
                    WhatsNewRootSheet(
                        entry: entry,
                        settingsActions: .init(store: libraryStore),
                        onDismiss: { whatsNew.dismissPresentedEntry() }
                    )
                }
                .presentationDetents([.large])
            }
            .onAppear(perform: updateWhatsNewPresentation)
            .onChange(of: keyStorage.key) { _, _ in
                updateWhatsNewPresentation()
            }
            .globalToasts()
=======
struct VlogSlateApp: App {
    @State private var isRecipeMode = false
    @State private var recipeStore = RecipeStore()
    @State private var store = VlogSlateStore()

    var body: some Scene {
        WindowGroup {
            if isRecipeMode {
                RecipeTabView(toggleMode: toggleMode)
                    .environment(recipeStore)
                    .transition(.opacity)
            } else {
                VlogSlateTabView(toggleMode: toggleMode)
                    .environment(store)
                    .transition(.opacity)
            }
        }
    }

    private func toggleMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isRecipeMode.toggle()
>>>>>>> Stashed changes
        }
    }

    private var presentedWhatsNewEntry: Binding<WhatsNewEntry?> {
        Binding(
            get: { whatsNew.presentedEntry },
            set: { newValue in
                if let newValue {
                    whatsNew.presentedEntry = newValue
                } else {
                    whatsNew.dismissPresentedEntry()
                }
            }
        )
    }

    private func updateWhatsNewPresentation() {
        whatsNew.presentIfNeeded(allowsAutoPresentation: hasTMDbAPIKey)
    }

    private var hasTMDbAPIKey: Bool {
        guard let key = keyStorage.key else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

<<<<<<< Updated upstream
fileprivate struct WhatsNewRootSheet: View {
    let entry: WhatsNewEntry
    let onDismiss: () -> Void

    @State private var actionRunner: WhatsNewActionRunner

    init(
        entry: WhatsNewEntry,
        settingsActions: LibraryProfileSettingsActions,
        onDismiss: @escaping () -> Void
    ) {
        self.entry = entry
        self.onDismiss = onDismiss
        _actionRunner = State(initialValue: settingsActions.makeWhatsNewActionRunner())
    }

    var body: some View {
        WhatsNewView(
            entry: entry,
            actionRunner: actionRunner,
            onDismiss: onDismiss
        )
=======
// MARK: - VlogSlate Mode

struct VlogSlateTabView: View {
    var toggleMode: () -> Void
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("片库", systemImage: "list.bullet", value: 0) {
                FootageShelfView(toggleMode: toggleMode)
            }
            Tab("场记", systemImage: "viewfinder", value: 1) {
                SlateControllerView()
            }
            Tab("扫码", systemImage: "qrcode.viewfinder", value: 2) {
                ScannerView()
            }
            Tab(value: 3, role: .search) {
                FootageSearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
>>>>>>> Stashed changes
    }
}

// MARK: - Recipe Mode

struct RecipeTabView: View {
    var toggleMode: () -> Void
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("菜谱", systemImage: "book", value: 0) {
                RecipeShelfView(toggleMode: toggleMode)
            }
            Tab("食材", systemImage: "carrot", value: 1) {
                ShoppingListView()
            }
            Tab("制作", systemImage: "frying.pan", value: 2) {
                CookingView()
            }
            Tab("计价", systemImage: "dollarsign.circle", value: 3) {
                PriceCalculatorView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
