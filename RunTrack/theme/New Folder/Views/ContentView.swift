import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Résumé", systemImage: "chart.bar.fill")
                }
            ActivitiesView()
                .tabItem {
                    Label("Activités", systemImage: "list.bullet")
                }
            RunRecorderView()
                .tabItem {
                    Label("Enregistrer", systemImage: "figure.run.circle.fill")
                }
            RecordsView()
                .tabItem {
                    Label("Progression", systemImage: "trophy.fill")
                }
            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
        .environmentObject(AuthManager())
}
