import SwiftUI
import FirebaseAuth

/// Affiche le profil public d'un autre utilisateur, avec un bouton Suivre et un bouton Encourager.
struct PublicProfileView: View {
    let profile: PublicProfile

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var socialManager: SocialManager

    @State private var isFollowing = false
    @State private var isLoading = true
    @State private var isSendingEncouragement = false
    @State private var encouragementJustSent = false

    private var isOwnProfile: Bool {
        Auth.auth().currentUser?.uid == profile.id
    }

    var body: some View {
        VStack(spacing: 16) {
            AvatarView(url: profile.photoURL, name: profile.name)
                .frame(width: 90, height: 90)

            Text(profile.name)
                .font(.title3)
                .bold()
                .foregroundStyle(.white)

            if let username = profile.username {
                Text("@\(username)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if profile.isMentor {
                Label("Mentor", systemImage: "star.fill")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(AppTheme.accent)
            }

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .appCard()
                    .padding(.horizontal, 24)
            }

            if isLoading {
                ProgressView()
            } else if !isOwnProfile {
                VStack(spacing: 10) {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        Text(isFollowing ? "Suivi(e)" : "Suivre")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isFollowing ? AppTheme.separator : AppTheme.accent)

                    Button {
                        Task { await sendEncouragement() }
                    } label: {
                        Label(
                            encouragementJustSent ? "Encouragement envoyé" : "Encourager",
                            systemImage: encouragementJustSent ? "checkmark" : "hands.clap.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                    .disabled(isSendingEncouragement || encouragementJustSent)
                }
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding(.top, 30)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let currentUid = Auth.auth().currentUser?.uid else {
                isLoading = false
                return
            }
            isFollowing = await socialManager.isFollowing(currentUserId: currentUid, targetUserId: profile.id)
            isLoading = false
        }
    }

    private func toggleFollow() async {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        do {
            if isFollowing {
                try await socialManager.unfollow(currentUserId: currentUid, targetUserId: profile.id)
            } else {
                try await socialManager.follow(currentUserId: currentUid, targetUserId: profile.id)
            }
            isFollowing.toggle()
        } catch {
            // Non bloquant pour ce soir.
        }
        isLoading = false
    }

    private func sendEncouragement() async {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        isSendingEncouragement = true
        do {
            try await socialManager.sendEncouragement(from: currentUid, to: profile.id)
            encouragementJustSent = true
        } catch {
            // Non bloquant.
        }
        isSendingEncouragement = false

        // Réautorise un nouvel encouragement après quelques secondes.
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        encouragementJustSent = false
    }
}
