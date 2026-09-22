import Foundation

/// Calcule les séries de courses (streaks) par semaine : au moins une course par semaine civile.
enum StreakCalculator {

    /// Série en cours (jusqu'à aujourd'hui). Ne casse pas la série si la semaine actuelle n'a pas encore de course.
    static func currentStreak(sessions: [RunSession], today: Date = Date(), calendar: Calendar = .current) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let weeksWithRuns = Set(sessions.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.startDate)?.start })

        var cursor = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        if !weeksWithRuns.contains(cursor) {
            // Pas encore couru cette semaine : on ne casse pas la série tant qu'elle n'est pas terminée.
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while weeksWithRuns.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    /// La plus longue série jamais atteinte dans l'historique.
    static func longestStreak(sessions: [RunSession], calendar: Calendar = .current) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let weeks = Set(sessions.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.startDate)?.start }).sorted()
        guard !weeks.isEmpty else { return 0 }

        var longest = 1
        var current = 1
        for index in 1..<weeks.count {
            let expectedNext = calendar.date(byAdding: .weekOfYear, value: 1, to: weeks[index - 1])
            if weeks[index] == expectedNext {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
