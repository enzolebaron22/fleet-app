import SwiftUI
import FirebaseAuth

/// Fil d'actualité : liste des encouragements reçus, avec le nom de l'expéditeur.
struct FeedView: View {
    @EnvironmentObject var socialManager: SocialManager

    @State private var items: [FeedItem] = []
    @State private var isLoading = true

    struct FeedItem: Identifiable {
        let id: String
        let senderName: String
        let senderPhotoURL: URL?
        let createdAt: Date
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            AvatarView(url: item.senderPhotoURL, name: item.senderName)
                                .frame(width: 44, height: 44)

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
                        .padding(.vertical, 4)
                        .listRowBackground(AppTheme.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Fil d'actualité")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFeed()
        }
        .refreshable {
            await loadFeed()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hands.clap.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Pas encore d'encouragement")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Quand quelqu'un t'encourage, ça apparaîtra ici.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadFeed() async {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        isLoading = true
        let encouragements = await socialManager.fetchEncouragementsReceived(userId: currentUid)

        var profileCache: [String: PublicProfile] = [:]
        var loadedItems: [FeedItem] = []

        for encouragement in encouragements {
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
                FeedItem(
                    id: encouragement.id,
                    senderName: profile?.name ?? "Quelqu'un",
                    senderPhotoURL: profile?.photoURL,
                    createdAt: encouragement.createdAt
                )
            )
        }

        items = loadedItems
        isLoading = false
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        FeedView()
            .environmentObject(SocialManager())
    }
}
