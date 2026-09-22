import Foundation

struct MonthComparison {
    let currentMonthKm: Double
    let previousMonthKm: Double

    var differenceKm: Double { currentMonthKm - previousMonthKm }
    var isImprovement: Bool { differenceKm >= 0 }
}

enum MonthComparisonCalculator {
    static func compare(sessions: [RunSession], calendar: Calendar = .current, today: Date = Date()) -> MonthComparison {
        guard let currentMonthInterval = calendar.dateInterval(of: .month, for: today) else {
            return MonthComparison(currentMonthKm: 0, previousMonthKm: 0)
        }
        guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthInterval.start),
              let previousMonthInterval = calendar.dateInterval(of: .month, for: previousMonthStart) else {
            return MonthComparison(currentMonthKm: 0, previousMonthKm: 0)
        }

        let currentKm = sessions.filter { currentMonthInterval.contains($0.startDate) }.reduce(0) { $0 + $1.distanceKm }
        let previousKm = sessions.filter { previousMonthInterval.contains($0.startDate) }.reduce(0) { $0 + $1.distanceKm }

        return MonthComparison(currentMonthKm: currentKm, previousMonthKm: previousKm)
    }
}
