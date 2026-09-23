import Foundation
import CoreLocation
import Combine

/// Suit la position GPS en direct pendant un enregistrement de course.
@MainActor
final class LocationTracker: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var isPaused = false
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var distanceMeters: Double = 0
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var currentLocation: CLLocationCoordinate2D?

    /// Allure actuelle en secondes par kilomètre, calculée à partir du temps et de la distance écoulés.
    var paceSecondsPerKm: Double {
        guard distanceMeters > 0 else { return 0 }
        return elapsedSeconds / (distanceMeters / 1000)
    }

    private let locationManager = CLLocationManager()
    private var collectedLocations: [CLLocation] = []
    private var lastLocation: CLLocation?
    private var startDate: Date?
    private var timer: Timer?
    private var accumulatedPausedSeconds: TimeInterval = 0
    private var pauseStartDate: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        // Aucun filtre de distance minimum : on veut TOUTES les positions GPS,
        // y compris dans les virages serrés (passages piétons, ronds-points).
        // Le tri du bruit se fait ensuite via la précision et la vitesse dans didUpdateLocations.
        locationManager.distanceFilter = kCLDistanceFilterNone
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func start() {
        collectedLocations = []
        routeCoordinates = []
        distanceMeters = 0
        elapsedSeconds = 0
        accumulatedPausedSeconds = 0
        lastLocation = nil
        startDate = Date()
        isTracking = true
        isPaused = false
        locationManager.startUpdatingLocation()
        startTimer()
    }

    func pause() {
        guard isTracking, !isPaused else { return }
        isPaused = true
        pauseStartDate = Date()
        locationManager.stopUpdatingLocation()
        stopTimer()
    }

    func resume() {
        guard isTracking, isPaused else { return }
        if let pauseStartDate {
            accumulatedPausedSeconds += Date().timeIntervalSince(pauseStartDate)
        }
        self.pauseStartDate = nil
        isPaused = false
        lastLocation = nil // évite un saut de distance artificiel après la pause
        locationManager.startUpdatingLocation()
        startTimer()
    }

    /// Arrête l'enregistrement et retourne les données collectées pour sauvegarde.
    func stop() -> (locations: [CLLocation], distanceMeters: Double, duration: TimeInterval, startDate: Date, endDate: Date)? {
        guard let startDate else { return nil }
        isTracking = false
        isPaused = false
        locationManager.stopUpdatingLocation()
        stopTimer()
        let endDate = Date()
        return (collectedLocations, distanceMeters, elapsedSeconds, startDate, endDate)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsedTime() {
        guard let startDate else { return }
        elapsedSeconds = Date().timeIntervalSince(startDate) - accumulatedPausedSeconds
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                // Ignore les points GPS peu précis (immeubles, arbres, signal faible).
                guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 20 else { continue }

                // Ignore les positions "en retard" (mise en cache par iOS), sources de sauts.
                guard abs(location.timestamp.timeIntervalSinceNow) < 5 else { continue }

                if let last = self.lastLocation {
                    let distance = location.distance(from: last)
                    let timeDelta = location.timestamp.timeIntervalSince(last.timestamp)

                    // Ignore les sauts irréalistes (vitesse > 20 km/h ≈ 5.5 m/s, largement au-dessus
                    // d'une allure de course, signe d'une erreur GPS plutôt que d'un vrai déplacement).
                    if timeDelta > 0 {
                        let speed = distance / timeDelta
                        guard speed < 5.5 else { continue }
                    }

                    // Ignore les micro-mouvements (bruit GPS à l'arrêt ou quasi à l'arrêt),
                    // sans filtrer les vrais petits déplacements dans un virage.
                    guard distance > 1 else { continue }

                    self.distanceMeters += distance
                }

                self.lastLocation = location
                self.collectedLocations.append(location)
                self.routeCoordinates.append(location.coordinate)
                self.currentLocation = location.coordinate
            }
        }
    }
}
