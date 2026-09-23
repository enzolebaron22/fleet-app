import SwiftUI

/// Feuille permettant de modifier sa date de naissance et son poids depuis le profil.
struct PersonalInfoEditSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var birthDate: Date
    @State private var weightKg: Double
    @State private var isSaving = false

    init() {
        _birthDate = State(initialValue: Date())
        _weightKg = State(initialValue: 70)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date de naissance") {
                    DatePicker("", selection: $birthDate, in: Calendar.current.date(byAdding: .year, value: -100, to: Date())!...Calendar.current.date(byAdding: .year, value: -8, to: Date())!, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }

                Section("Poids") {
                    VStack(spacing: 8) {
                        Text("\(Int(weightKg)) kg")
                            .font(.title2)
                            .bold()
                        Stepper("", value: $weightKg, in: 30...200, step: 1)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Mes infos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                if let currentBirthDate = authManager.birthDate {
                    birthDate = currentBirthDate
                }
                if let currentWeight = authManager.weightKg {
                    weightKg = currentWeight
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        await authManager.updatePublicProfile(birthDate: birthDate, weightKg: weightKg)
        isSaving = false
        dismiss()
    }
}

#Preview {
    PersonalInfoEditSheet()
        .environmentObject(AuthManager())
}
