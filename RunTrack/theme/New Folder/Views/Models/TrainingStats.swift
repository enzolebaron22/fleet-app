import Foundation

/// Statistiques agrégées sur une période (ex : 7 derniers jours, 4 dernières semaines).
struct TrainingStats {
    let sessions: [RunSession]

    var totalDistanceKm: Double {
        sessions.reduce(0) { $0 + $1.distanceKm }
    }

    var totalDurationSeconds: Double {
        sessions.reduce(0) { $0 + $1.durationSeconds }
    }

    var sessionCount: Int {
        sessions.count
    }

    var averagePaceSecondsPerKm: Double {
        guard totalDistanceKm > 0 else { return 0 }
        return totalDurationSeconds / totalDistanceKm
    }

    var bestPaceSession: RunSession? {
        sessions.filter { $0.distanceKm >= 1 }.min { $0.paceSecondsPerKm < $1.paceSecondsPerKm }
    }

    var longestSession: RunSession? {
        sessions.max { $0.distanceKm < $1.distanceKm }
    }

    var averageHeartRate: Double? {
        let values = sessions.compactMap { $0.averageHeartRate }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
