import SwiftUI
import GoogleSignInSwift

/// Écran affiché au premier lancement (et tant que l'utilisateur n'est pas connecté).
/// Inspiré des écrans d'accueil "plein cadre" des grandes apps de sport : logo en haut,
/// accroche et boutons en bas. En attendant une vraie photo de fond, on utilise un dégradé sombre animé.
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var animateGlow = false

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Image("FleetLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fleet")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Suis tes courses, progresse chaque semaine.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.75))
                }

                if authManager.isSigningIn {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 12) {
                        Button {
                            authManager.signInWithGoogle()
                        } label: {
                            Text("S'inscrire")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }

                        Button {
                            authManager.signInWithGoogle()
                        } label: {
                            Text("Se connecter")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .overlay(
                                    Capsule().stroke(Color.white, lineWidth: 1.5)
                                )
                        }
                    }
                }

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.09, blue: 0.06),
                    AppTheme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [AppTheme.accent.opacity(0.3), .clear],
                center: animateGlow ? .topTrailing : .topLeading,
                startRadius: 0,
                endRadius: animateGlow ? 550 : 400
            )
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
