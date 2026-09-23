import SwiftUI

/// Vue racine : affiche un court écran de démarrage animé, puis bascule
/// vers l'écran de connexion ou l'app principale selon l'état de connexion.
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSplash = true
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @AppStorage("hasSkippedGoalOnboarding") private var hasSkippedGoalOnboarding: Bool = false

    private var needsGoalOnboarding: Bool {
        authManager.isSignedIn && authManager.hasLoadedProfile && authManager.goal == nil && !hasSkippedGoalOnboarding
    }

    var body: some View {
        ZStack {
            if showSplash {
                splashView
                    .transition(.opacity)
            } else if authManager.isSignedIn {
                ContentView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: .constant(needsGoalOnboarding)) {
            OnboardingGoalView()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }

    private var splashView: some View {
        ZStack {
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
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 450
                )
            }
            .ignoresSafeArea()

            Image("FleetLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 140)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthManager())
        .environmentObject(HealthKitManager())
        .environmentObject(NotificationManager())
}
