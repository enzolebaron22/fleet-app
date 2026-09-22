import SwiftUI
import MapKit
import CoreLocation

/// Écran d'enregistrement d'une course en direct : carte, tracé GPS, stats en temps réel.
struct RunRecorderView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var locationTracker = LocationTracker()

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.2),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )
    @State private var hasCenteredOnStart = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var showSummary = false
    @State private var lastRunSummary: (distanceKm: Double, duration: TimeInterval, pace: Double)?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, interactionModes: .all) {
                    if !locationTracker.routeCoordinates.isEmpty {
                        MapPolyline(coordinates: locationTracker.routeCoordinates)
                            .stroke(AppTheme.accent, lineWidth: 4)
                    }
                    if let current = locationTracker.currentLocation {
                        Annotation("", coordinate: current) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .ignoresSafeArea(edges: .top)
                .onChange(of: locationTracker.routeCoordinates.count) { _, newCount in
                    guard newCount > 0, !hasCenteredOnStart, let newValue = locationTracker.currentLocation else { return }
                    hasCenteredOnStart = true
                    cameraPosition = .region(
                        MKCoordinateRegion(center: newValue, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    )
                }

                VStack(spacing: 16) {
                    statsPanel
                    controlButtons
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding()
            }
            .navigationTitle("Enregistrer")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationTracker.requestAuthorization()
            }
            .alert("Erreur", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showSummary) {
                if let lastRunSummary {
                    RunSummaryView(
                        distanceKm: lastRunSummary.distanceKm,
                        duration: lastRunSummary.duration,
                        paceSecondsPerKm: lastRunSummary.pace
                    ) {
                        showSummary = false
                    }
                }
            }
        }
    }

    private var statsPanel: some View {
        HStack {
            statColumn(title: "Temps", value: formattedTime(locationTracker.elapsedSeconds))
            Spacer()
            statColumn(title: "Allure moy.", value: displayedPace)
            Spacer()
            statColumn(title: "Distance", value: String(format: "%.2f km", locationTracker.distanceMeters / 1000))
        }
    }

    /// Affiche "--:--" pendant les 8 premières secondes : le calcul est trop instable
    /// juste au démarrage (peu de distance parcourue face au temps déjà écoulé).
    private var displayedPace: String {
        guard locationTracker.elapsedSeconds >= 8 else { return "--:--" }
        return formattedPace(locationTracker.paceSecondsPerKm)
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .bold()
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var controlButtons: some View {
        if !locationTracker.isTracking {
            Button {
                hasCenteredOnStart = false
                locationTracker.start()
            } label: {
                Label("Démarrer", systemImage: "play.fill")
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        } else {
            HStack(spacing: 12) {
                Button {
                    if locationTracker.isPaused {
                        locationTracker.resume()
                    } else {
                        locationTracker.pause()
                    }
                } label: {
                    Label(locationTracker.isPaused ? "Reprendre" : "Pause", systemImage: locationTracker.isPaused ? "play.fill" : "pause.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }

                Button(role: .destructive) {
                    stopAndSave()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .disabled(isSaving)
            }
        }
    }

    private func stopAndSave() {
        guard let result = locationTracker.stop() else { return }
        // Évite de sauvegarder un arrêt accidentel trop court (moins de 10 secondes).
        guard result.duration >= 10 else { return }

        isSaving = true
        Task {
            do {
                try await healthKitManager.saveRun(
                    locations: result.locations,
                    distanceMeters: result.distanceMeters,
                    duration: result.duration,
                    startDate: result.startDate,
                    endDate: result.endDate
                )
                let paceSecondsPerKm = result.distanceMeters > 0 ? result.duration / (result.distanceMeters / 1000) : 0
                lastRunSummary = (result.distanceMeters / 1000, result.duration, paceSecondsPerKm)
                showSummary = true
            } catch {
                saveErrorMessage = "Impossible de sauvegarder la course : \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func formattedPace(_ secondsPerKm: Double) -> String {
        guard secondsPerKm > 0, secondsPerKm.isFinite else { return "--:--" }
        let totalSeconds = Int(secondsPerKm)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

#Preview {
    RunRecorderView()
        .environmentObject(HealthKitManager())
}
