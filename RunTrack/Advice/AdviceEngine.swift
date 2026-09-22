import Foundation

/// Un conseil généré à partir des tendances récentes de l'utilisateur.
struct TrainingAdvice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: Severity

    enum Severity {
        case info, warning, success
    }
}

/// Moteur de règles : analyse l'historique complet des séances pour générer des conseils.
/// Pensé pour être remplacé/complété plus tard par un modèle plus fin (Core ML)
/// sans changer l'interface appelante.
enum AdviceEngine {

    static func generateAdvice(from sessions: [RunSession]) -> [TrainingAdvice] {
        var advice: [TrainingAdvice] = []

        let calendar = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) else {
            return advice
        }

        let thisWeek = sessions.filter { $0.startDate >= sevenDaysAgo }
        let lastWeek = sessions.filter { $0.startDate >= fourteenDaysAgo && $0.startDate < sevenDaysAgo }

        let thisWeekStats = TrainingStats(sessions: thisWeek)
        let lastWeekStats = TrainingStats(sessions: lastWeek)

        // Pas de séance cette semaine : on distingue une pause courte d'une pause longue.
        if thisWeek.isEmpty {
            if let lastRunDate = sessions.map({ $0.startDate }).max() {
                let daysSince = calendar.dateComponents([.day], from: lastRunDate, to: now).day ?? 0
                if daysSince >= 14 {
                    advice.append(TrainingAdvice(
                        title: "Reprise en douceur",
                        message: "Ça fait \(daysSince) jours que tu n'as pas couru. Reprends avec 2-3 sorties faciles avant de retrouver ton rythme habituel, plutôt que de repartir directement sur ton allure d'avant.",
                        severity: .warning
                    ))
                } else {
                    advice.append(TrainingAdvice(
                        title: "Aucune sortie cette semaine",
                        message: "Tu n'as pas encore couru cette semaine. Une sortie facile de 20-30 minutes suffit pour relancer la dynamique.",
                        severity: .warning
                    ))
                }
            } else {
                advice.append(TrainingAdvice(
                    title: "Aucune sortie cette semaine",
                    message: "Tu n'as pas encore couru cette semaine. Une sortie facile de 20-30 minutes suffit pour relancer la dynamique.",
                    severity: .warning
                ))
            }
            return advice
        }

        // Tendance de volume : on compare à la moyenne des 4 dernières semaines plutôt qu'à
        // une seule semaine, pour lisser les variations ponctuelles (une semaine chargée ou
        // creuse isolée ne déclenche pas une fausse alerte).
        if let baseline = averageWeeklyDistance(sessions: sessions, weeksBack: 4, before: sevenDaysAgo, calendar: calendar),
           baseline > 0 {
            let ratio = thisWeekStats.totalDistanceKm / baseline
            if ratio > 1.4 {
                advice.append(TrainingAdvice(
                    title: "Charge en hausse rapide",
                    message: String(format: "Ton volume cette semaine (%.1f km) dépasse de %.0f%% ta moyenne des 4 dernières semaines (%.1f km). Garde au moins une sortie facile pour limiter le risque de blessure.", thisWeekStats.totalDistanceKm, (ratio - 1) * 100, baseline),
                    severity: .warning
                ))
            } else if ratio < 0.6 {
                advice.append(TrainingAdvice(
                    title: "Baisse de volume",
                    message: String(format: "Ton volume cette semaine (%.1f km) est nettement en dessous de ta moyenne récente (%.1f km). Si c'est une semaine de récupération voulue, très bien ; sinon essaie d'ajouter une sortie.", thisWeekStats.totalDistanceKm, baseline),
                    severity: .info
                ))
            }
        }

        // Allure qui progresse (comparaison directe à la semaine dernière, plus réactive)
        if lastWeekStats.averagePaceSecondsPerKm > 0 && thisWeekStats.averagePaceSecondsPerKm > 0 {
            let paceDelta = lastWeekStats.averagePaceSecondsPerKm - thisWeekStats.averagePaceSecondsPerKm
            if paceDelta > 10 {
                advice.append(TrainingAdvice(
                    title: "Allure en progression",
                    message: String(format: "Ton allure moyenne s'est améliorée de %.0f secondes/km par rapport à la semaine dernière. Continue sur cette lancée, sans négliger la récupération.", paceDelta),
                    severity: .success
                ))
            }
        }

        // Fréquence des sorties
        if thisWeekStats.sessionCount == 1 {
            advice.append(TrainingAdvice(
                title: "Une seule sortie cette semaine",
                message: "Une seule séance peut suffire à maintenir la forme, mais 2-3 sorties régulières apportent une progression plus stable.",
                severity: .info
            ))
        } else if thisWeekStats.sessionCount >= 5 {
            advice.append(TrainingAdvice(
                title: "Volume de séances élevé",
                message: "5 sorties ou plus cette semaine : assure-toi d'avoir au moins un jour de repos complet pour bien récupérer.",
                severity: .warning
            ))
        }

        // Une sortie longue qui domine largement le volume de la semaine
        if thisWeekStats.sessionCount > 1,
           let longest = thisWeekStats.longestSession,
           thisWeekStats.totalDistanceKm > 0 {
            let longRunRatio = longest.distanceKm / thisWeekStats.totalDistanceKm
            if longRunRatio > 0.5 {
                advice.append(TrainingAdvice(
                    title: "Sortie longue très dominante",
                    message: String(format: "Ta plus longue sortie (%.1f km) représente plus de la moitié de ton volume cette semaine (%.1f km). Répartir davantage sur plusieurs sorties plus courtes réduit le risque de blessure.", longest.distanceKm, thisWeekStats.totalDistanceKm),
                    severity: .info
                ))
            }
        }

        // FC moyenne élevée sur plusieurs séances
        if let avgHR = thisWeekStats.averageHeartRate, avgHR > 165 {
            advice.append(TrainingAdvice(
                title: "Fréquence cardiaque moyenne élevée",
                message: String(format: "Ta FC moyenne cette semaine (%.0f bpm) est assez haute. Vérifie que tu intègres bien des sorties en endurance fondamentale, pas seulement des efforts intenses.", avgHR),
                severity: .warning
            ))
        }

        // Nouveau record personnel battu cette semaine
        let eligibleSessions = sessions.filter { $0.distanceKm >= 1 }
        if eligibleSessions.count > 1,
           let weekBest = thisWeekStats.bestPaceSession,
           let allTimeBest = PersonalRecordsCalculator.bestPaceEver(from: sessions),
           weekBest.id == allTimeBest.id {
            advice.append(TrainingAdvice(
                title: "Nouveau record personnel !",
                message: "Ta meilleure allure jamais enregistrée (\(weekBest.paceFormatted)) date de cette semaine. Bravo — pense à bien récupérer après cet effort.",
                severity: .success
            ))
        }

        if advice.isEmpty {
            advice.append(TrainingAdvice(
                title: "Tout est stable",
                message: "Ta charge d'entraînement est cohérente avec tes dernières semaines. Continue comme ça !",
                severity: .success
            ))
        }

        return advice
    }

    /// Moyenne du volume hebdomadaire sur les `weeksBack` semaines précédant `referenceDate`.
    private static func averageWeeklyDistance(
        sessions: [RunSession],
        weeksBack: Int,
        before referenceDate: Date,
        calendar: Calendar
    ) -> Double? {
        guard let startDate = calendar.date(byAdding: .day, value: -7 * weeksBack, to: referenceDate) else {
            return nil
        }
        let relevant = sessions.filter { $0.startDate >= startDate && $0.startDate < referenceDate }
        guard !relevant.isEmpty else { return nil }
        let totalKm = relevant.reduce(0) { $0 + $1.distanceKm }
        return totalKm / Double(weeksBack)
    }
}
