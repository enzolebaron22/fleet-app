import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct RunTrackApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var authManager = AuthManager()
    @StateObject private var socialManager = SocialManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(healthKitManager)
                .environmentObject(notificationManager)
                .environmentObject(authManager)
                .environmentObject(socialManager)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
