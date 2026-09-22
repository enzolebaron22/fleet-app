import SwiftUI

/// Écran pour choisir son pseudo unique (une seule fois).
struct UsernameSetupSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var input: String = ""
    @State private var isChecking = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.count <= 20 && trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choisis ton pseudo")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                Text("3 à 20 caractères, lettres, chiffres et underscore uniquement. Impossible à changer pour l'instant.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("pseudo", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isChecking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Valider")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(!isValid || isChecking)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 12)
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

    private func save() async {
        isChecking = true
        errorMessage = nil

        let candidate = input.trimmingCharacters(in: .whitespaces)
        let available = await authManager.isUsernameAvailable(candidate)
        guard available else {
            errorMessage = "Ce pseudo est déjà pris."
            isChecking = false
            return
        }

        do {
            try await authManager.setUsername(candidate)
            dismiss()
        } catch {
            errorMessage = "Une erreur est survenue, réessaie."
        }
        isChecking = false
    }
}

#Preview {
    UsernameSetupSheet()
        .environmentObject(AuthManager())
}
