import Foundation

struct WeeklyDistancePoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let distanceKm: Double
}

enum WeeklyTrendCalculator {
    /// Distance totale par semaine sur les `weeksCount` dernières semaines (la plus récente en dernier).
    static func weeklyDistances(sessions: [RunSession], weeksCount: Int = 8, calendar: Calendar = .current, today: Date = Date()) -> [WeeklyDistancePoint] {
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }

        var points: [WeeklyDistancePoint] = []
        for offset in stride(from: weeksCount - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }
            let distance = sessions.filter { weekInterval.contains($0.startDate) }.reduce(0) { $0 + $1.distanceKm }
            points.append(WeeklyDistancePoint(weekStart: weekStart, distanceKm: distance))
        }
        return points
    }
}
