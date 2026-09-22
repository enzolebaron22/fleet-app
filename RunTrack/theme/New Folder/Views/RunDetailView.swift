import SwiftUI
import CoreLocation

struct RunDetailView: View {
    let session: RunSession
    @EnvironmentObject var healthKitManager: HealthKitManager

    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var showShareActivity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(session.startDate, style: .date)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)

                RouteMapView(session: session)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    DetailCard(title: "Distance", value: String(format: "%.2f km", session.distanceKm))
                    DetailCard(title: "Durée", value: session.durationFormatted)
                    DetailCard(title: "Allure", value: session.paceFormatted)
                    if let hr = session.averageHeartRate {
                        DetailCard(title: "FC moyenne", value: String(format: "%.0f bpm", hr))
                    }
                    if let calories = session.activeCalories {
                        DetailCard(title: "Calories", value: String(format: "%.0f kcal", calories))
                    }
                    if let elevation = session.elevationGainMeters {
                        DetailCard(title: "Dénivelé+", value: String(format: "%.0f m", elevation))
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Détail de la course")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareActivity = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(AppTheme.accent)
            }
        }
        .task {
            routeCoordinates = await healthKitManager.fetchRoute(for: session)
        }
        .sheet(isPresented: $showShareActivity) {
            ShareActivitySheet(session: session, coordinates: routeCoordinates)
        }
    }
}

private struct DetailCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

#Preview {
    NavigationStack {
        RunDetailView(session: RunSession(
            id: UUID(),
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            distanceMeters: 5200,
            durationSeconds: 1800,
            averageHeartRate: 152,
            activeCalories: 320,
            elevationGainMeters: 45
        ))
        .environmentObject(HealthKitManager())
    }
}
