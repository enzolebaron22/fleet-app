import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var showSettings = false
    @State private var feedItems: [FeedView.FeedItem] = []
    @State private var isLoadingFeed = true
    @AppStorage("weeklyGoalKm") private var weeklyGoalKm: Double = 15

    private var firstName: String {
        authManager.userName.split(separator: " ").first.map(String.init) ?? ""
    }

    private var weekStats: TrainingStats {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = healthKitManager.runSessions.filter { $0.startDate >= sevenDaysAgo }
        return TrainingStats(sessions: recent)
    }

    private var advice: [TrainingAdvice] {
        AdviceEngine.generateAdvice(from: healthKitManager.runSessions)
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(sessions: healthKitManager.runSessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    summaryCards
                    feedSection
                    adviceSection
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Résumé")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("FleetLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 22)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Réservé pour les futures notifications push (voir roadmap).
                    Button {
                    } label: {
                        Image(systemName: "bell.fill")
                    }
                    .tint(AppTheme.accent)
                    .opacity(0.4)
                    .disabled(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .tint(AppTheme.accent)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .refreshable {
                await healthKitManager.fetchRunningSessions()
                await loadFeed()
            }
            .task {
                if !healthKitManager.isAuthorized {
                    await healthKitManager.requestAuthorization()
                } else {
                    await healthKitManager.fetchRunningSessions()
                }
            }
            .task {
                await loadFeed()
            }
        }
    }

    private var summaryCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !firstName.isEmpty {
                Text("Bonjour, \(firstName)")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.white)
            }

            if currentStreak > 0 {
                StreakBanner(streak: currentStreak)
            }

            Text("Cette semaine")
                .font(.headline)
                .foregroundStyle(.white)

            GoalProgressCard(currentKm: weekStats.totalDistanceKm, goalKm: weeklyGoalKm)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Distance", value: String(format: "%.1f km", weekStats.totalDistanceKm), icon: "figure.run")
                StatCard(title: "Séances", value: "\(weekStats.sessionCount)", icon: "calendar")
            }
        }
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fil d'actualité")
                .font(.headline)
                .foregroundStyle(.white)

            if isLoadingFeed {
                ProgressView()
                    .tint(AppTheme.accent)
            } else if feedItems.isEmpty {
                Text("Pas encore d'encouragement reçu. Ça apparaîtra ici dès que quelqu'un t'en enverra un !")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appCard()
            } else {
                ForEach(feedItems) { item in
                    HStack(spacing: 12) {
                        AvatarView(url: item.senderPhotoURL, name: item.senderName)
                            .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.senderName)
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.white)
                            Text("t'a envoyé un encouragement")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        Text(relativeDate(item.createdAt))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .appCard()
                }
            }
        }
    }

    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conseils")
                .font(.headline)
                .foregroundStyle(.white)

            if healthKitManager.isLoading {
                ProgressView()
                    .tint(AppTheme.accent)
            } else if advice.isEmpty {
                Text("Pas encore assez de données pour te conseiller. Enregistre quelques courses !")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .appCard()
            } else {
                ForEach(advice) { item in
                    AdviceRow(advice: item)
                }
            }
        }
    }

    private func paceString(_ secondsPerKm: Double) -> String {
        let totalSeconds = Int(secondsPerKm)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadFeed() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoadingFeed = false
            return
        }
        isLoadingFeed = true
        let encouragements = await socialManager.fetchEncouragementsReceived(userId: uid)

        var profileCache: [String: PublicProfile] = [:]
        var loadedItems: [FeedView.FeedItem] = []

        for encouragement in encouragements.prefix(5) {
            let profile: PublicProfile?
            if let cached = profileCache[encouragement.fromUserId] {
                profile = cached
            } else {
                profile = await socialManager.fetchPublicProfile(uid: encouragement.fromUserId)
                if let profile {
                    profileCache[encouragement.fromUserId] = profile
                }
            }
            loadedItems.append(
                FeedView.FeedItem(
                    id: encouragement.id,
                    senderName: profile?.name ?? "Quelqu'un",
                    senderPhotoURL: profile?.photoURL,
                    createdAt: encouragement.createdAt
                )
            )
        }

        feedItems = loadedItems
        isLoadingFeed = false
    }
}

private struct StreakBanner: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak) semaine\(streak > 1 ? "s" : "") de suite")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                Text("Continue comme ça !")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .appCard()
    }
}

private struct StatCard: View {
    let title: String
    let value: String
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

private struct GoalProgressCard: View {
    let currentKm: Double
    let goalKm: Double

    private var progress: Double {
        guard goalKm > 0 else { return 0 }
        return min(currentKm / goalKm, 1.0)
    }

    private var isReached: Bool {
        currentKm >= goalKm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Objectif hebdomadaire")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(String(format: "%.1f", currentKm)) / \(Int(goalKm)) km")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.separator)
                    Capsule()
                        .fill(isReached ? Color.green : AppTheme.accent)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 10)

            if isReached {
                Text("Objectif atteint 🎉")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .appCard()
    }
}

private struct AdviceRow: View {
    let advice: TrainingAdvice

    private var color: Color {
        switch advice.severity {
        case .info: return .blue
        case .warning: return AppTheme.accent
        case .success: return .green
        }
    }

    private var icon: String {
        switch advice.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(advice.title)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                Text(advice.message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .appCard()
    }
}

#Preview {
    DashboardView()
        .environmentObject(HealthKitManager())
        .environmentObject(AuthManager())
        .environmentObject(SocialManager())
}
