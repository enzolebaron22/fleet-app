import SwiftUI
import Charts

struct RecordsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var selectedBadge: Badge?

    private var records: [PersonalRecord] {
        PersonalRecordsCalculator.records(from: healthKitManager.runSessions)
    }

    private var longestRun: RunSession? {
        PersonalRecordsCalculator.longestRun(from: healthKitManager.runSessions)
    }

    private var bestPace: RunSession? {
        PersonalRecordsCalculator.bestPaceEver(from: healthKitManager.runSessions)
    }

    private var badgeContext: BadgeContext {
        BadgeContext(
            sessions: healthKitManager.runSessions,
            currentStreak: StreakCalculator.currentStreak(sessions: healthKitManager.runSessions),
            longestStreak: StreakCalculator.longestStreak(sessions: healthKitManager.runSessions)
        )
    }

    private var weeklyTrendPoints: [WeeklyDistancePoint] {
        WeeklyTrendCalculator.weeklyDistances(sessions: healthKitManager.runSessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    highlightsSection
                    weeklyTrendSection
                    badgesSection
                    distanceRecordsSection
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Progression")
            .overlay {
                if healthKitManager.runSessions.isEmpty && !healthKitManager.isLoading {
                    ContentUnavailableView(
                        "Aucun record pour l'instant",
                        systemImage: "trophy",
                        description: Text("Tes records apparaîtront ici dès que tu auras des courses enregistrées.")
                    )
                }
            }
            .refreshable {
                await healthKitManager.fetchRunningSessions()
            }
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailSheet(badge: badge, isUnlocked: badge.isUnlocked(badgeContext))
            }
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("En bref")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let longestRun {
                    RecordCard(
                        title: "Plus longue sortie",
                        value: String(format: "%.1f km", longestRun.distanceKm),
                        subtitle: dateString(longestRun.startDate),
                        icon: "arrow.up.right"
                    )
                }
                if let bestPace {
                    RecordCard(
                        title: "Meilleure allure",
                        value: bestPace.paceFormatted,
                        subtitle: dateString(bestPace.startDate),
                        icon: "bolt.fill"
                    )
                }
            }
        }
    }

    private var weeklyTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tendance (8 dernières semaines)")
                .font(.headline)
                .foregroundStyle(.white)

            if weeklyTrendPoints.allSatisfy({ $0.distanceKm == 0 }) {
                Text("Pas encore assez de données pour afficher une tendance.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appCard()
            } else {
                Chart(weeklyTrendPoints) { point in
                    AreaMark(
                        x: .value("Semaine", point.weekStart, unit: .weekOfYear),
                        y: .value("Distance", point.distanceKm)
                    )
                    .foregroundStyle(AppTheme.accent.opacity(0.15))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Semaine", point.weekStart, unit: .weekOfYear),
                        y: .value("Distance", point.distanceKm)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Semaine", point.weekStart, unit: .weekOfYear),
                        y: .value("Distance", point.distanceKm)
                    )
                    .foregroundStyle(AppTheme.accent)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let km = value.as(Double.self) {
                                Text("\(Int(km)) km")
                            }
                        }
                    }
                }
                .appCard()
            }
        }
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(BadgeCatalog.all) { badge in
                    BadgeCard(badge: badge, isUnlocked: badge.isUnlocked(badgeContext))
                        .onTapGesture {
                            selectedBadge = badge
                        }
                }
            }
        }
    }

    private var distanceRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Records par distance")
                .font(.headline)
                .foregroundStyle(.white)

            if records.isEmpty {
                Text("Pas encore de course proche d'une distance de référence (5 km, 10 km, semi, marathon).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appCard()
            } else {
                ForEach(records) { record in
                    NavigationLink(destination: RunDetailView(session: record.session)) {
                        RecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct RecordCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

private struct RecordRow: View {
    let record: PersonalRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.label)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                Text(record.session.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Text(record.session.paceFormatted)
                .font(.subheadline)
                .foregroundStyle(AppTheme.accent)
        }
        .appCard()
    }
}

private struct BadgeCard: View {
    let badge: Badge
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.iconName)
                .font(.title)
                .foregroundStyle(isUnlocked ? AppTheme.accent : AppTheme.textSecondary)
            Text(badge.title)
                .font(.caption)
                .bold()
                .multilineTextAlignment(.center)
                .foregroundStyle(isUnlocked ? .white : AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .opacity(isUnlocked ? 1.0 : 0.5)
        .appCard()
    }
}

private struct BadgeDetailSheet: View {
    let badge: Badge
    let isUnlocked: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: badge.iconName)
                    .font(.system(size: 50))
                    .foregroundStyle(isUnlocked ? AppTheme.accent : AppTheme.textSecondary)
                    .padding(.top, 20)

                Text(badge.title)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)

                Text(badge.detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                if isUnlocked {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conseil")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(AppTheme.accent)
                        Text(badge.tip)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
                } else {
                    Text("Badge pas encore débloqué")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .appCard()
                }

                Spacer()
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(AppTheme.accent)
                }
            }
        }
    }
}

#Preview {
    RecordsView()
        .environmentObject(HealthKitManager())
}
