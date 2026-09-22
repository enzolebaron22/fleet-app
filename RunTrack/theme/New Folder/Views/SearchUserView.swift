import SwiftUI

/// Recherche un utilisateur par son pseudo.
struct SearchUserView: View {
    @EnvironmentObject var socialManager: SocialManager

    @State private var input: String = ""
    @State private var isSearching = false
    @State private var foundProfile: PublicProfile?
    @State private var notFound = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    TextField("Pseudo de la personne", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        Task { await search() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .tint(AppTheme.accent)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                if isSearching {
                    ProgressView()
                } else if notFound {
                    Text("Aucun utilisateur avec ce pseudo.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else if let foundProfile {
                    NavigationLink(destination: PublicProfileView(profile: foundProfile)) {
                        HStack {
                            AvatarView(url: foundProfile.photoURL, name: foundProfile.name)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading) {
                                Text(foundProfile.name)
                                    .foregroundStyle(.white)
                                    .bold()
                                if let username = foundProfile.username {
                                    Text("@\(username)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .appCard()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Trouver des amis")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func search() async {
        isSearching = true
        notFound = false
        foundProfile = nil

        let candidate = input.trimmingCharacters(in: .whitespaces)
        if let uid = await AuthManager().findUser(byUsername: candidate) {
            foundProfile = await socialManager.fetchPublicProfile(uid: uid)
            notFound = foundProfile == nil
        } else {
            notFound = true
        }
        isSearching = false
    }
}
