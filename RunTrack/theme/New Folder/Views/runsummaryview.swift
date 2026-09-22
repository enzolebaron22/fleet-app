import SwiftUI

/// Écran de félicitations affiché juste après l'enregistrement d'une course.
struct RunSummaryView: View {
    let distanceKm: Double
    let duration: TimeInterval
    let paceSecondsPerKm: Double
    let onDone: () -> Void

    @State private var showCheckmark = false
    @State private var showStats = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.18, green: 0.09, blue: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ConfettiView()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(.orange)
                        .scaleEffect(showCheckmark ? 1 : 0.3)
                        .opacity(showCheckmark ? 1 : 0)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)

                Text("Bon travail !")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.white)
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 10)

                HStack(spacing: 28) {
                    summaryStat(title: "Distance", value: String(format: "%.2f km", distanceKm))
                    summaryStat(title: "Temps", value: formattedTime(duration))
                    summaryStat(title: "Allure", value: formattedPace(paceSecondsPerKm))
                }
                .opacity(showStats ? 1 : 0)
                .offset(y: showStats ? 0 : 10)

                Spacer()

                Button(action: onDone) {
                    Text("Terminé")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)
                .opacity(showStats ? 1 : 0)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            showCheckmark = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showStats = true
                }
            }
        }
    }

    private func summaryStat(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func formattedPace(_ secondsPerKm: Double) -> String {
        guard secondsPerKm > 0, secondsPerKm.isFinite else { return "--:--" }
        let totalSeconds = Int(secondsPerKm)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

/// Un petit effet de confettis qui tombent, sans dépendance externe.
private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let xOffset: CGFloat
    let rotation: Double
    let delay: Double
}

private struct ConfettiView: View {
    @State private var animate = false
    private let pieces: [ConfettiPiece]

    init(count: Int = 40) {
        let colors: [Color] = [.orange, .red, .yellow, .white]
        pieces = (0..<count).map { _ in
            ConfettiPiece(
                color: colors.randomElement() ?? .orange,
                xOffset: CGFloat.random(in: -160...160),
                rotation: Double.random(in: 0...360),
                delay: Double.random(in: 0...0.4)
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: 8, height: 14)
                    .rotationEffect(.degrees(animate ? piece.rotation + 360 : piece.rotation))
                    .offset(x: piece.xOffset, y: animate ? 500 : -50)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeIn(duration: 1.8).delay(piece.delay), value: animate)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    RunSummaryView(distanceKm: 5.2, duration: 1800, paceSecondsPerKm: 346, onDone: {})
}
