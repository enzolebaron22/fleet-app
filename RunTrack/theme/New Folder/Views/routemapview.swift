import SwiftUI
import MapKit

/// Affiche le tracé GPS d'une séance sur une carte, si elle en a un.
struct RouteMapView: View {
    let session: RunSession
    @EnvironmentObject var healthKitManager: HealthKitManager

    @State private var coordinates: [CLLocationCoordinate2D] = []
    @State private var isLoading = true
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
            } else if !coordinates.isEmpty {
                Map(position: $cameraPosition, interactionModes: .all) {
                    // Contour blanc en dessous pour que le tracé ressorte sur tout type de terrain.
                    MapPolyline(coordinates: coordinates)
                        .stroke(Color.white, lineWidth: 7)
                    MapPolyline(coordinates: coordinates)
                        .stroke(Color.orange, lineWidth: 4)
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            // Si aucune coordonnée n'est trouvée (course sans GPS), on n'affiche rien.
        }
        .task {
            let points = await healthKitManager.fetchRoute(for: session)
            coordinates = points
            if let region = MapRegionHelper.region(for: points) {
                cameraPosition = .region(region)
            }
            isLoading = false
        }
    }
}
