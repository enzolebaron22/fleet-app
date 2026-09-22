import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var showSignOutConfirmation = false
    @AppStorage("weeklyGoalKm") private var weeklyGoalKm: Double = 15

    private let weekdays: [(value: Int, label: String)] = [
        (1, "Dimanche"), (2, "Lundi"), (3, "Mardi"), (4, "Mercredi"),
        (5, "Jeudi"), (6, "Vendredi"), (7, "Samedi")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(url: authManager.userPhotoURL, name: authManager.userName)
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.userName.isEmpty ? "Utilisateur" : authManager.userName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Voir mon profil")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink {
                        SearchUserView()
                    } label: {
                        Label("Trouver des amis", systemImage: "person.2.fill")
                    }
                }
                .listRowBackground(AppTheme.card)

                Section {
                    Toggle("Rappel hebdomadaire", isOn: Binding(
                        get: { notificationManager.isWeeklyReminderEnabled },
                        set: { newValue in
                            if newValue {
                                Task {
                                    await notificationManager.requestAuthorizationIfNeeded()
                                    if notificationManager.isAuthorized {
                                        notificationManager.isWeeklyReminderEnabled = true
                                    }
                                }
                            } else {
                                notificationManager.isWeeklyReminderEnabled = false
                            }
                        }
                    ))
                    .tint(AppTheme.accent)
                } footer: {
                    Text("Reçois une notification pour te rappeler de prévoir ta sortie de la semaine.")
                }
                .listRowBackground(AppTheme.card)

                if notificationManager.isWeeklyReminderEnabled {
                    Section("Quand ?") {
                        Picker("Jour", selection: $notificationManager.reminderWeekday) {
                            ForEach(weekdays, id: \.value) { day in
                                Text(day.label).tag(day.value)
                            }
                        }
                        DatePicker(
                            "Heure",
                            selection: Binding(
                                get: {
                                    var components = DateComponents()
                                    components.hour = notificationManager.reminderHour
                                    components.minute = notificationManager.reminderMinute
                                    return Calendar.current.date(from: components) ?? Date()
                                },
                                set: { newDate in
                                    let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                    notificationManager.reminderHour = components.hour ?? 18
                                    notificationManager.reminderMinute = components.minute ?? 0
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .tint(AppTheme.accent)
                    }
                    .listRowBackground(AppTheme.card)
                }

                Section {
                    Stepper(value: $weeklyGoalKm, in: 5...100, step: 5) {
                        HStack {
                            Text("Objectif hebdomadaire")
                            Spacer()
                            Text("\(Int(weeklyGoalKm)) km")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                } footer: {
                    Text("Utilisé pour la barre de progression affichée sur l'écran Résumé.")
                }
                .listRowBackground(AppTheme.card)

                if !notificationManager.isAuthorized {
                    Section {
                        Text("Les notifications sont désactivées pour RunTrack. Active-les dans Réglages iOS > RunTrack > Notifications pour recevoir les rappels.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .listRowBackground(AppTheme.card)
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Text("Se déconnecter")
                    }
                }
                .listRowBackground(AppTheme.card)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Réglages")
            .task {
                await notificationManager.requestAuthorizationIfNeeded()
            }
            .confirmationDialog(
                "Se déconnecter de Fleet ?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Se déconnecter", role: .destructive) {
                    authManager.signOut()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(NotificationManager())
        .environmentObject(AuthManager())
        .environmentObject(HealthKitManager())
}
