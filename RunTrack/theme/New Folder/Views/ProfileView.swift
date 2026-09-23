import SwiftUI

/// Page de profil de l'utilisateur : photo, nom, pseudo, bio, date d'inscription et statistiques all-time.
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var showUsernameSetup = false
    @State private var showBioEdit = false
    @State private var showSearch = false

    private var allSessions: [RunSession] { healthKitManager.runSessions }

    private var totalDistanceKm: Double {
        allSessions.reduce(0) { $0 + $1.distanceKm }
    }

    private var totalSessions: Int { allSessions.count }

    private var longestStreak: Int {
        StreakCalculator.longestStreak(sessions: allSessions)
    }

    private var averageDistanceKm: Double {
        totalSessions > 0 ? totalDistanceKm / Double(totalSessions) : 0
    }

    private var memberSinceText: String? {
        guard let date = authManager.memberSince else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return "Membre depuis \(formatter.string(from: date).capitalized)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        AvatarView(url: authManager.userPhotoURL, name: authManager.userName)
                            .frame(width: 96, height: 96)

                        Text(authManager.userName.isEmpty ? "Utilisateur" : authManager.userName)
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.white)

                        if let username = authManager.username {
                            Text("@\(username)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.accent)
                        } else {
                            Button {
                                showUsernameSetup = true
                            } label: {
                                Text("Choisir un pseudo")
                                    .font(.caption)
                                    .bold()
                            }
                            .tint(AppTheme.accent)
                        }

                        if let memberSinceText {
                            Text(memberSinceText)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.top, 20)

                    bioSection

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ProfileStatCard(title: "Distance totale", value: String(format: "%.1f km", totalDistanceKm), icon: "figure.run")
                        ProfileStatCard(title: "Sorties", value: "\(totalSessions)", icon: "calendar")
                        ProfileStatCard(title: "Plus longue série", value: "\(longestStreak) sem.", icon: "flame.fill")
                        ProfileStatCard(title: "Distance moyenne", value: String(format: "%.1f km", averageDistanceKm), icon: "chart.bar.fill")
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Mon profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .tint(AppTheme.accent)
                }
            }
            .sheet(isPresented: $showUsernameSetup) {
                UsernameSetupSheet()
            }
            .sheet(isPresented: $showBioEdit) {
                BioEditSheet()
            }
            .sheet(isPresented: $showSearch) {
                NavigationStack {
                    SearchUserView()
                }
            }
        }
    }

    @ViewBuilder
    private var bioSection: some View {
        Button {
            showBioEdit = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Bio")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let bio = authManager.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Ajouter une bio")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding()
            .appCard()
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

/// Photo de profil (ou initiales si pas de photo) affichée en cercle.
struct AvatarView: View {
    let url: URL?
    let name: String

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.separator, lineWidth: 1))
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(AppTheme.accent.opacity(0.3))
            Text(initials)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
}

private struct ProfileStatCard: View {
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

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(HealthKitManager())
}
