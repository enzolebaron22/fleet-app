import SwiftUI

/// Calendrier mensuel : les jours avec une course ont un fond coloré, dont l'intensité
/// varie selon la distance parcourue ce jour-là (comme une heatmap).
/// Le jour le plus récent avec une course s'affiche automatiquement en dessous.
struct CalendarMonthView: View {
    let sessions: [RunSession]

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date?

    private var calendar: Calendar { Calendar.current }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: displayedMonth).capitalized
    }

    /// Grille des jours du mois affiché, avec des cases vides (nil) avant le 1er du mois
    /// pour que la semaine commence bien un lundi.
    private var daysInMonthGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyCount = (firstWeekday + 5) % 7 // décale pour que la semaine démarre le lundi

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyCount)
        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? monthInterval.end
        }
        return days
    }

    private var sessionsInDisplayedMonth: [RunSession] {
        sessions.filter { calendar.isDate($0.startDate, equalTo: displayedMonth, toGranularity: .month) }
    }

    private var monthTotalKm: Double {
        sessionsInDisplayedMonth.reduce(0) { $0 + $1.distanceKm }
    }

    private func sessions(on date: Date) -> [RunSession] {
        sessions.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    /// Le jour le plus récent du mois affiché où une course a eu lieu (pour la présélection).
    private var mostRecentRunDate: Date? {
        sessionsInDisplayedMonth
            .map { calendar.startOfDay(for: $0.startDate) }
            .max()
    }

    /// La plus grosse distance parcourue en un seul jour, ce mois-ci — sert de référence pour l'intensité des couleurs.
    private var maxDailyKmInMonth: Double {
        let dailyTotals = Dictionary(grouping: sessionsInDisplayedMonth, by: { calendar.startOfDay(for: $0.startDate) })
            .mapValues { $0.reduce(0) { $0 + $1.distanceKm } }
        return dailyTotals.values.max() ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthHeader
                monthSummary
                weekdayHeader

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(Array(daysInMonthGrid.enumerated()), id: \.offset) { _, date in
                        if let date {
                            DayCell(
                                date: date,
                                dayTotalKm: sessions(on: date).reduce(0) { $0 + $1.distanceKm },
                                maxDailyKm: maxDailyKmInMonth,
                                isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                            )
                            .onTapGesture {
                                let runsThatDay = sessions(on: date)
                                guard !runsThatDay.isEmpty else { return }
                                selectedDate = date
                            }
                        } else {
                            Color.clear.frame(height: 52)
                        }
                    }
                }
                .padding(.horizontal)

                if let selectedDate {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(sessions(on: selectedDate)) { session in
                            NavigationLink(destination: RunDetailView(session: session)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(String(format: "%.1f", session.distanceKm)) km")
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(.white)
                                        Text(session.paceFormatted)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .appCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                } else if sessionsInDisplayedMonth.isEmpty {
                    Text("Aucune course ce mois-ci.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 8)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            selectedDate = mostRecentRunDate
        }
        .onChange(of: displayedMonth) { _, _ in
            selectedDate = mostRecentRunDate
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthTitle)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .tint(AppTheme.accent)
        .padding(.horizontal)
    }

    private var monthSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f km", monthTotalKm))
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.white)
                Text("\(sessionsInDisplayedMonth.count) sortie\(sessionsInDisplayedMonth.count > 1 ? "s" : "") ce mois-ci")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var weekdayHeader: some View {
        let symbols = ["L", "M", "M", "J", "V", "S", "D"]
        return HStack {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

private struct DayCell: View {
    let date: Date
    let dayTotalKm: Double
    let maxDailyKm: Double
    let isSelected: Bool

    private var hasRun: Bool { dayTotalKm > 0 }

    /// Intensité entre 0 et 1, par rapport à la plus grosse journée du mois affiché.
    private var intensity: Double {
        guard hasRun, maxDailyKm > 0 else { return 0 }
        return dayTotalKm / maxDailyKm
    }

    /// Couleur de fond selon l'intensité, par paliers façon heatmap (GitHub-style).
    private var fillColor: Color {
        guard hasRun else { return .clear }
        switch intensity {
        case ..<0.25:
            return AppTheme.accent.opacity(0.35)
        case ..<0.5:
            return AppTheme.accent.opacity(0.55)
        case ..<0.75:
            return AppTheme.accent.opacity(0.8)
        default:
            return AppTheme.accent
        }
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.subheadline)
                .fontWeight(hasRun || isToday ? .bold : .regular)
                .foregroundStyle(hasRun ? .white : (isToday ? AppTheme.accent : .white))

            if hasRun {
                Text(String(format: "%.1f", dayTotalKm))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isToday && !hasRun ? AppTheme.accent : Color.clear, lineWidth: 1.5)
        )
    }
}

#Preview {
    NavigationStack {
        CalendarMonthView(sessions: [])
    }
}
