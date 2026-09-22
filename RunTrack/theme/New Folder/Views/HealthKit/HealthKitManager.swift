import Foundation
import HealthKit
import Combine
import CoreLocation

/// Centralise toutes les interactions avec HealthKit : autorisation et récupération des séances de course.
@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var runSessions: [RunSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Types de données qu'on lit depuis HealthKit.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKSeriesType.workoutRoute()
        ]
        if let elevation = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(elevation)
        }
        return types
    }

    /// Types de données qu'on écrit dans HealthKit (pour enregistrer une course faite dans l'app).
    private var writeTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKSeriesType.workoutRoute()
        ]
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit n'est pas disponible sur cet appareil."
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            await fetchRunningSessions()
        } catch {
            errorMessage = "Autorisation refusée ou impossible : \(error.localizedDescription)"
        }
    }

    /// Sauvegarde une course enregistrée dans l'app (avec son tracé GPS) dans HealthKit.
    func saveRun(locations: [CLLocation], distanceMeters: Double, duration: TimeInterval, startDate: Date, endDate: Date) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        try await builder.beginCollection(at: startDate)

        let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
        let distanceSample = HKQuantitySample(
            type: HKQuantityType(.distanceWalkingRunning),
            quantity: distanceQuantity,
            start: startDate,
            end: endDate
        )
        try await builder.addSamples([distanceSample])

        try await builder.endCollection(at: endDate)
        guard let workout = try await builder.finishWorkout() else {
            throw NSError(domain: "RunTrack", code: 1, userInfo: [NSLocalizedDescriptionKey: "Impossible de finaliser la séance."])
        }

        if !locations.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            try await routeBuilder.insertRouteData(locations)
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }

        await fetchRunningSessions()
    }

    /// Récupère toutes les séances de type "course à pied" des N derniers jours (90 par défaut).
    func fetchRunningSessions(daysBack: Int = 90) async {
        isLoading = true
        defer { isLoading = false }

        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())
        let datePredicate: NSPredicate = startDate.map {
            HKQuery.predicateForSamples(withStart: $0, end: Date(), options: .strictStartDate)
        } ?? NSPredicate(value: true)

        do {
            let allWorkouts = try await fetchWorkouts(matching: datePredicate)
            let workouts = allWorkouts.filter { $0.workoutActivityType == .running }

            var sessions: [RunSession] = []
            for workout in workouts {
                let heartRate = try? await averageHeartRate(for: workout)
                let session = RunSession(
                    id: workout.uuid,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    distanceMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                    durationSeconds: workout.duration,
                    averageHeartRate: heartRate,
                    activeCalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                    elevationGainMeters: workout.metadata?[HKMetadataKeyElevationAscended] as? Double
                )
                sessions.append(session)
            }
            self.runSessions = sessions.sorted { $0.startDate > $1.startDate }
        } catch {
            errorMessage = "Erreur lors de la récupération des séances : \(error.localizedDescription)"
        }
    }

    private func fetchWorkouts(matching predicate: NSPredicate) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    /// Récupère les coordonnées GPS du parcours d'une séance (si elle en a un).
    func fetchRoute(for session: RunSession) async -> [CLLocationCoordinate2D] {
        do {
            guard let workout = try await fetchWorkout(withID: session.id) else { return [] }
            let routes = try await fetchWorkoutRoutes(for: workout)

            var allLocations: [CLLocation] = []
            for route in routes {
                let locations = try await fetchLocations(for: route)
                allLocations.append(contentsOf: locations)
            }
            return allLocations.map { $0.coordinate }
        } catch {
            return []
        }
    }

    private func fetchWorkout(withID id: UUID) async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObject(with: id)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout])?.first)
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkoutRoutes(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { continuation in
            var collected: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: route) { _, locationsOrNil, done, errorOrNil in
                if let error = errorOrNil {
                    continuation.resume(throwing: error)
                    return
                }
                if let locations = locationsOrNil {
                    collected.append(contentsOf: locations)
                }
                if done {
                    continuation.resume(returning: collected)
                }
            }
            healthStore.execute(query)
        }
    }

    private func averageHeartRate(for workout: HKWorkout) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictStartDate
            )
            let quantityType = HKQuantityType(.heartRate)
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                let value = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}
