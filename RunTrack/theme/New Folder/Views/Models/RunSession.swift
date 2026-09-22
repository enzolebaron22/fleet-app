import Foundation

/// Représente une séance de course, construite à partir des données HealthKit.
struct RunSession: Identifiable, Codable, Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double        // distance totale en mètres
    let durationSeconds: Double       // durée totale en secondes
    let averageHeartRate: Double?     // bpm, optionnel (pas toujours dispo)
    let activeCalories: Double?       // kcal, optionnel
    let elevationGainMeters: Double?  // dénivelé positif, optionnel

    /// Allure moyenne en secondes par kilomètre.
    var paceSecondsPerKm: Double {
        guard distanceMeters > 0 else { return 0 }
        return durationSeconds / (distanceMeters / 1000)
    }

    /// Allure formatée "mm:ss / km"
    var paceFormatted: String {
        let totalSeconds = Int(paceSecondsPerKm)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var distanceKm: Double {
        distanceMeters / 1000
    }

    var durationFormatted: String {
        let totalSeconds = Int(durationSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh%02dm%02ds", hours, minutes, seconds)
        }
        return String(format: "%dm%02ds", minutes, seconds)
    }
}
