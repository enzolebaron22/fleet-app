import Foundation

/// Un record personnel : la meilleure séance pour une distance de référence donnée.
struct PersonalRecord: Identifiable {
    let id = UUID()
    let label: String
    let session: RunSession
}

/// Calcule les records personnels à partir de l'historique des courses.
enum PersonalRecordsCalculator {

    /// Distances de référence (label, distance en km, tolérance en % pour matcher des courses proches).
    private static let standardDistances: [(label: String, km: Double, tolerance: Double)] = [
        ("5 km", 5.0, 0.08),
        ("10 km", 10.0, 0.08),
        ("Semi-marathon", 21.1, 0.05),
        ("Marathon", 42.2, 0.05)
    ]

    /// Meilleur temps pour chaque distance de référence où l'utilisateur a au moins une course correspondante.
    static func records(from sessions: [RunSession]) -> [PersonalRecord] {
        var results: [PersonalRecord] = []
        for distance in standardDistances {
            let matching = sessions.filter {
                abs($0.distanceKm - distance.km) <= distance.km * distance.tolerance
            }
            if let best = matching.min(by: { $0.paceSecondsPerKm < $1.paceSecondsPerKm }) {
                results.append(PersonalRecord(label: distance.label, session: best))
            }
        }
        return results
    }

    /// La course la plus longue jamais enregistrée.
    static func longestRun(from sessions: [RunSession]) -> RunSession? {
        sessions.max(by: { $0.distanceMeters < $1.distanceMeters })
    }

    /// La meilleure allure jamais atteinte, toutes distances confondues.
    static func bestPaceEver(from sessions: [RunSession]) -> RunSession? {
        sessions.filter { $0.distanceKm >= 1.0 }
            .min(by: { $0.paceSecondsPerKm < $1.paceSecondsPerKm })
    }
}
