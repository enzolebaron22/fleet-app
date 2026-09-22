import SwiftUI
import MapKit

/// Vue d'ensemble : affiche tous les parcours GPS enregistrés sur une seule carte.
struct MapOverviewView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager

    @State private var routes: [(id: UUID, coordinates: [CLLocationCoordinate2D])] = []
    @State private var isLoading = true
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.2), // Centre approximatif de la France
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // La carte est toujours affichée, même sans parcours enregistré.
                Map(position: $cameraPosition, interactionModes: .all) {
                    ForEach(routes, id: \.id) { route in
                        MapPolyline(coordinates: route.coordinates)
                            .stroke(Color.orange, lineWidth: 3)
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .ignoresSafeArea(edges: .bottom)

                if !isLoading && routes.isEmpty {
                    Text("Aucun parcours GPS pour l'instant")
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Carte")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadRoutes()
            }
            .refreshable {
                await loadRoutes()
            }
        }
    }

    private func loadRoutes() async {
        isLoading = true
        var collected: [(id: UUID, coordinates: [CLLocationCoordinate2D])] = []

        for session in healthKitManager.runSessions {
            let coordinates = await healthKitManager.fetchRoute(for: session)
            if !coordinates.isEmpty {
                collected.append((id: session.id, coordinates: coordinates))
            }
        }

        routes = collected

        let allCoordinates = collected.flatMap { $0.coordinates }
        if let region = MapRegionHelper.region(for: allCoordinates) {
            cameraPosition = .region(region)
        }
        isLoading = false
    }
}

#Preview {
    MapOverviewView()
        .environmentObject(HealthKitManager())
}
