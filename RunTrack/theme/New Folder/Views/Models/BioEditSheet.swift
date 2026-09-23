import SwiftUI

/// Écran d'édition de la bio publique de l'utilisateur.
struct BioEditSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var isSaving = false

    private let characterLimit = 150

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Parle un peu de toi : ton objectif, pourquoi tu cours, ce que tu aimes...")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)

                TextEditor(text: $text)
                    .frame(height: 140)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: text) { _, newValue in
                        if newValue.count > characterLimit {
                            text = String(newValue.prefix(characterLimit))
                        }
                    }

                Text("\(text.count)/\(characterLimit)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Ma bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "..." : "Enregistrer") {
                        Task {
                            isSaving = true
                            await authManager.updatePublicProfile(bio: text)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .onAppear {
            text = authManager.bio ?? ""
        }
    }
}

#Preview {
    BioEditSheet()
        .environmentObject(AuthManager())
}
