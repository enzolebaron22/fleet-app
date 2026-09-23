import SwiftUI

/// Feuille permettant de changer son objectif depuis le profil.
struct GoalSetupSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(GoalCatalog.all) { option in
                        Button {
                            Task { await select(option) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: option.icon)
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundStyle(.white)
                                    Text(option.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer()

                                if authManager.goal == option.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .padding()
                            .appCard()
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Mon objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
        }
    }

    private func select(_ option: GoalOption) async {
        isSaving = true
        await authManager.updatePublicProfile(goal: option.id)
        isSaving = false
        dismiss()
    }
}

#Preview {
    GoalSetupSheet()
        .environmentObject(AuthManager())
}
