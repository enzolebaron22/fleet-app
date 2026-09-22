import SwiftUI
import MapKit

/// Fusionne l'historique des courses, un calendrier et la carte d'ensemble, avec un sélecteur pour basculer entre les trois.
struct ActivitiesView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var locationProvider = CurrentLocationProvider()

    private enum Display: String, CaseIterable {
        case list = "Liste"
        case calendar = "Calendrier"
        case map = "Carte"
    }

    @State private var selectedDisplay: Display = .list

    // État pour l'affichage carte
    @State private var routes: [(id: UUID, coordinates: [CLLocationCoordinate2D])] = []
    @State private var isLoadingRoutes = true
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.2),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )

    // État pour la génération de boucle
    @State private var showLoopSheet = false
    @State private var selectedLoopDistance: Double = 5
    @State private var isGeneratingLoop = false
    @State private var generatedLoop: [CLLocationCoordinate2D] = []
    @State private var loopErrorMessage: String?

    private let nearbyThresholdMeters: CLLocationDistance = 400

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Affichage", selection: $selectedDisplay) {
                    ForEach(Display.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.accent)
                .padding()

                switch selectedDisplay {
                case .list:
                    listContent
                case .calendar:
                    CalendarMonthView(sessions: healthKitManager.runSessions)
                case .map:
                    mapContent
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Activités")
            .task {
                await loadRoutes()
            }
        }
    }

    private var listContent: some View {
        List(healthKitManager.runSessions) { session in
            NavigationLink(destination: RunDetailView(session: session)) {
                RunRow(session: session)
            }
            .listRowBackground(AppTheme.background)
            .listRowSeparatorTint(AppTheme.separator)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .overlay {
            if healthKitManager.runSessions.isEmpty && !healthKitManager.isLoading {
                ContentUnavailableView(
                    "Aucune course",
                    systemImage: "figure.run",
                    description: Text("Tes sorties de course apparaîtront ici une fois synchronisées avec Santé.")
                )
            }
        }
        .refreshable {
            await healthKitManager.fetchRunningSessions()
            await loadRoutes()
        }
    }

    private var mapContent: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, interactionModes: .all) {
                ForEach(routes, id: \.id) { route in
                    let nearby = isNearby(route.coordinates)
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(nearby ? Color.green : AppTheme.accent.opacity(0.35), lineWidth: nearby ? 4 : 3)
                }

                if !generatedLoop.isEmpty {
                    MapPolyline(coordinates: generatedLoop)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }

                if let current = locationProvider.location {
                    Annotation("Ma position", coordinate: current) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 10) {
                if !isLoadingRoutes && routes.isEmpty && generatedLoop.isEmpty {
                    Text("Aucun parcours GPS pour l'instant")
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                if let loopErrorMessage {
                    Text(loopErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                }

                Button {
                    showLoopSheet = true
                } label: {
                    if isGeneratingLoop {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    } else {
                        Label("Générer une boucle", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.subheadline)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .disabled(isGeneratingLoop)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            locationProvider.requestLocation()
        }
        .refreshable {
            await loadRoutes()
        }
        .sheet(isPresented: $showLoopSheet) {
            loopDistanceSheet
        }
    }

    private var loopDistanceSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choisis la distance souhaitée pour ta boucle. Le parcours généré suit les chemins existants et reste approximatif.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Picker("Distance", selection: $selectedLoopDistance) {
                    ForEach([3.0, 5.0, 8.0, 10.0, 15.0], id: \.self) { distance in
                        Text("\(Int(distance)) km").tag(distance)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.accent)
                .padding(.horizontal)

                Button {
                    showLoopSheet = false
                    generateLoop()
                } label: {
                    Text("Générer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal)
                .disabled(locationProvider.location == nil)

                if locationProvider.location == nil {
                    Text("En attente de ta position...")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.top, 30)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Nouvelle boucle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { showLoopSheet = false }
                        .tint(AppTheme.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func isNearby(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard let current = locationProvider.location else { return false }
        let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
        return coordinates.contains { coordinate in
            let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return point.distance(from: currentLocation) <= nearbyThresholdMeters
        }
    }

    private func generateLoop() {
        guard let current = locationProvider.location else { return }
        loopErrorMessage = nil
        isGeneratingLoop = true
        generatedLoop = []

        Task {
            let loop = await RouteGenerator.generateLoop(from: current, distanceKm: selectedLoopDistance)
            if let loop {
                generatedLoop = loop
                if let region = MapRegionHelper.region(for: loop) {
                    cameraPosition = .region(region)
                }
            } else {
                loopErrorMessage = "Impossible de générer une boucle ici. Réessaie ou choisis une autre distance."
            }
            isGeneratingLoop = false
        }
    }

    private func loadRoutes() async {
        isLoadingRoutes = true
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
        isLoadingRoutes = false
    }
}

private struct RunRow: View {
    let session: RunSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startDate, style: .date)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                Text("\(String(format: "%.1f", session.distanceKm)) km · \(session.durationFormatted)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Text(session.paceFormatted)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ActivitiesView()
        .environmentObject(HealthKitManager())
}
