import SwiftUI
import SwiftData

@main
struct SpendbookApp: App {
    @State private var budget = BudgetStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(budget)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(DataStore.container)
    }
}

enum AppTab: Hashable {
    case home, history, insights, budget, add
}

struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var showAdd = false

    var body: some View {
        // The "Add" tab uses the search role so iOS draws it as the separate
        // round Liquid Glass button beside the tab bar. Tapping it opens the
        // Add Spend sheet instead of switching tabs.
        let selection = Binding<AppTab>(
            get: { tab },
            set: { newValue in
                if newValue == .add { showAdd = true } else { tab = newValue }
            }
        )

        TabView(selection: selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(showAdd: $showAdd)
            }
            Tab("History", systemImage: "clock.fill", value: AppTab.history) {
                HistoryView()
            }
            Tab("Insights", systemImage: "chart.pie.fill", value: AppTab.insights) {
                InsightsView()
            }
            Tab("Budget", systemImage: "target", value: AppTab.budget) {
                BudgetView()
            }
            Tab("Add", systemImage: "plus", value: AppTab.add, role: .search) {
                Color.black
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showAdd) {
            AddSpendView()
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
    }
}
