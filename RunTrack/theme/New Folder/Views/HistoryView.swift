import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {
        NavigationStack {
            List(healthKitManager.runSessions) { session in
                NavigationLink(destination: RunDetailView(session: session)) {
                    RunRow(session: session)
                }
            }
            .navigationTitle("Historique")
            .overlay {
                if healthKitManager.runSessions.isEmpty && !healthKitManager.isLoading {
                    ContentUnavailableView(
                        "Aucune course",
                        systemImage: "figure.run",
                        description: Text("Tes sorties de course apparaîtront ici une fois synchronisées avec Santé.")
                    )
                }
            }
            .refreshable {
                await healthKitManager.fetchRunningSessions()
            }
        }
    }
}

private struct RunRow: View {
    let session: RunSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startDate, style: .date)
                    .font(.subheadline)
                    .bold()
                Text("\(String(format: "%.1f", session.distanceKm)) km · \(session.durationFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(session.paceFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .environmentObject(HealthKitManager())
}
