import SwiftUI

private enum OnboardingStep {
    case username
    case birthDate
    case weight
    case goal
    case followUp
    case recap
}

/// Écran affiché automatiquement à la première connexion : pseudo, date de naissance, poids,
/// choix de l'objectif, une question de suivi adaptée, puis un récap avant d'entrer dans l'app.
struct OnboardingGoalView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var notificationManager: NotificationManager
    @AppStorage("hasSkippedGoalOnboarding") private var hasSkippedGoalOnboarding: Bool = false
    @AppStorage("weeklyGoalKm") private var weeklyGoalKm: Double = 15

    @State private var step: OnboardingStep = .username
    @State private var selectedGoal: GoalOption?
    @State private var isSaving = false

    // Étape pseudo
    @State private var usernameInput: String = ""
    @State private var usernameError: String?
    @State private var isCheckingUsername = false

    // Étape date de naissance
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

    // Étape poids
    @State private var weightKg: Double = 70

    // Réponses de suivi, selon l'objectif choisi
    @State private var chosenWeeklyGoal: Double?
    @State private var reminderWeekday: Int = 2
    @State private var reminderHour: Int = 18

    private let weekdays: [(value: Int, label: String)] = [
        (1, "Dimanche"), (2, "Lundi"), (3, "Mardi"), (4, "Mercredi"),
        (5, "Jeudi"), (6, "Vendredi"), (7, "Samedi")
    ]

    private var isUsernameFormatValid: Bool {
        let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.count <= 20 else { return false }
        return trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    var body: some View {
        ScrollView {
            switch step {
            case .username:
                usernameStep
            case .birthDate:
                birthDateStep
            case .weight:
                weightStep
            case .goal:
                goalStep
            case .followUp:
                followUpStep
            case .recap:
                recapStep
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Étape 1 : pseudo

    private var usernameStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Bienvenue sur Fleet 👋")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                Text("Choisis un pseudo, c'est comme ça que les autres te trouveront.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Pseudo", text: $usernameInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .appCard()

                if let usernameError {
                    Text(usernameError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)

            Button {
                Task { await confirmUsername() }
            } label: {
                if isCheckingUsername {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continuer")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(!isUsernameFormatValid || isCheckingUsername)
            .padding(.horizontal)

            Button("Plus tard") {
                step = .birthDate
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.bottom, 30)
        }
    }

    private func confirmUsername() async {
        isCheckingUsername = true
        usernameError = nil
        let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
        let available = await authManager.isUsernameAvailable(trimmed)
        if available {
            do {
                try await authManager.setUsername(trimmed)
                step = .birthDate
            } catch {
                usernameError = error.localizedDescription
            }
        } else {
            usernameError = "Ce pseudo est déjà pris, essaie-en un autre."
        }
        isCheckingUsername = false
    }

    // MARK: - Étape 2 : date de naissance

    private var birthDateStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Ta date de naissance")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                Text("Ça ne sera jamais affiché publiquement — juste utile pour mieux adapter tes conseils.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.horizontal)

            DatePicker(
                "Date de naissance",
                selection: $birthDate,
                in: Calendar.current.date(byAdding: .year, value: -100, to: Date())!...Calendar.current.date(byAdding: .year, value: -8, to: Date())!,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding(.horizontal)

            Button {
                step = .weight
            } label: {
                Text("Continuer")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .padding(.horizontal)

            Button("Plus tard") {
                step = .weight
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Étape 3 : poids

    private var weightStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Ton poids")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                Text("Ça ne sera jamais affiché publiquement — juste utile pour mieux adapter tes conseils.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.horizontal)

            VStack(spacing: 12) {
                Text("\(Int(weightKg)) kg")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                Stepper("", value: $weightKg, in: 30...200, step: 1)
                    .labelsHidden()
            }
            .padding()
            .appCard()
            .padding(.horizontal)

            Button {
                step = .goal
            } label: {
                Text("Continuer")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .padding(.horizontal)

            Button("Plus tard") {
                step = .goal
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Étape 4 : choix de l'objectif

    private var goalStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Un dernier truc")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                Text("Qu'est-ce qui te ferait le plus plaisir ici ?")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(GoalCatalog.all) { option in
                    Button {
                        selectedGoal = option
                        if hasFollowUp(for: option.id) {
                            step = .followUp
                        } else {
                            step = .recap
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.icon)
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 28)

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
                        }
                        .padding()
                        .appCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Button("Plus tard") {
                hasSkippedGoalOnboarding = true
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Étape 5 : question de suivi

    private func hasFollowUp(for goalId: String) -> Bool {
        ["first_run", "health", "race", "consistency"].contains(goalId)
    }

    @ViewBuilder
    private var followUpStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: selectedGoal?.icon ?? "figure.run")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.accent)
                Text(followUpQuestion)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 50)
            .padding(.horizontal)

            if selectedGoal?.id == "consistency" {
                reminderPicker
            } else {
                weeklyGoalChoices
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal)
    }

    private var followUpQuestion: String {
        switch selectedGoal?.id {
        case "first_run": return "Tu as déjà un peu couru, ou c'est vraiment le début ?"
        case "health": return "Combien de fois par semaine tu penses pouvoir courir ?"
        case "race": return "Quelle distance tu vises ?"
        case "consistency": return "Quel jour te va le mieux pour qu'on te motive ?"
        default: return ""
        }
    }

    private var weeklyGoalChoices: some View {
        VStack(spacing: 12) {
            ForEach(followUpOptions, id: \.label) { choice in
                Button {
                    chosenWeeklyGoal = choice.weeklyKm
                    step = .recap
                } label: {
                    Text(choice.label)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .appCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var followUpOptions: [(label: String, weeklyKm: Double)] {
        switch selectedGoal?.id {
        case "first_run":
            return [
                ("Jamais couru", 5),
                ("Un peu, de temps en temps", 10),
                ("Je m'entraîne déjà régulièrement", 15)
            ]
        case "health":
            return [
                ("1 fois par semaine", 5),
                ("2 à 3 fois par semaine", 12),
                ("4 fois ou plus", 20)
            ]
        case "race":
            return [
                ("10 km", 15),
                ("Semi-marathon", 25),
                ("Marathon", 35)
            ]
        default:
            return []
        }
    }

    private var reminderPicker: some View {
        VStack(spacing: 16) {
            Picker("Jour", selection: $reminderWeekday) {
                ForEach(weekdays, id: \.value) { day in
                    Text(day.label).tag(day.value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)

            DatePicker(
                "Heure",
                selection: Binding(
                    get: {
                        var components = DateComponents()
                        components.hour = reminderHour
                        return Calendar.current.date(from: components) ?? Date()
                    },
                    set: { newDate in
                        reminderHour = Calendar.current.component(.hour, from: newDate)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .tint(AppTheme.accent)
            .appCard()

            Button {
                step = .recap
            } label: {
                Text("Continuer")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
    }

    // MARK: - Étape 6 : récap

    private var recapStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 60)

            Text("C'est parti !")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                if let selectedGoal {
                    recapRow(icon: selectedGoal.icon, text: selectedGoal.title)
                }
                if let chosenWeeklyGoal {
                    recapRow(icon: "figure.run", text: "Objectif hebdo réglé sur \(Int(chosenWeeklyGoal)) km — modifiable à tout moment dans les Réglages")
                }
                if selectedGoal?.id == "consistency" {
                    recapRow(icon: "bell.fill", text: "Rappel programmé le \(weekdays.first(where: { $0.value == reminderWeekday })?.label ?? "") à \(reminderHour)h")
                }
            }
            .padding()
            .appCard()
            .padding(.horizontal)

            Button {
                Task { await finish() }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Entrer dans Fleet")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(isSaving)
            .padding(.horizontal)
            .padding(.top, 12)

            Spacer(minLength: 30)
        }
    }

    private func recapRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Sauvegarde finale

    private func finish() async {
        guard let selectedGoal else { return }
        isSaving = true

        if let chosenWeeklyGoal {
            weeklyGoalKm = chosenWeeklyGoal
        }

        if selectedGoal.id == "consistency" {
            await notificationManager.requestAuthorizationIfNeeded()
            if notificationManager.isAuthorized {
                notificationManager.reminderWeekday = reminderWeekday
                notificationManager.reminderHour = reminderHour
                notificationManager.reminderMinute = 0
                notificationManager.isWeeklyReminderEnabled = true
            }
        }

        await authManager.updatePublicProfile(goal: selectedGoal.id, birthDate: birthDate, weightKg: weightKg)
        isSaving = false
    }
}

#Preview {
    OnboardingGoalView()
        .environmentObject(AuthManager())
        .environmentObject(NotificationManager())
}
