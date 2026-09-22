import SwiftUI
import CoreLocation

/// Carte récap générée pour le partage : logo, tracé en silhouette, distance et stats principales.
/// - Fond coloré : carte complète avec dégradé (pour un post classique).
/// - Transparent : stats qui flottent directement sur la photo, sans carte (façon sticker Strava).
struct ShareCardView: View {
    let session: RunSession
    let coordinates: [CLLocationCoordinate2D]
    var transparent: Bool = false

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: session.startDate).capitalized
    }

    var body: some View {
        Group {
            if transparent {
                transparentOverlay
            } else {
                filledCard
            }
        }
        .frame(width: 1080, height: 1080)
    }

    // MARK: - Style "fond coloré"

    private var filledCard: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                HStack {
                    Image("FleetLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 34)
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.horizontal, 60)

                Spacer()

                if !coordinates.isEmpty {
                    RouteSilhouetteView(coordinates: coordinates)
                        .frame(height: 340)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(String(format: "%.2f", session.distanceKm))
                        .font(.system(size: 96, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("KILOMÈTRES")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(4)
                }

                Spacer().frame(height: 50)

                HStack(spacing: 0) {
                    ShareStat(value: session.durationFormatted, label: "DURÉE")
                    ShareDivider()
                    ShareStat(value: session.paceFormatted, label: "ALLURE")
                    if let calories = session.activeCalories {
                        ShareDivider()
                        ShareStat(value: String(format: "%.0f", calories), label: "KCAL")
                    }
                }
                .padding(.horizontal, 60)

                Spacer().frame(height: 50)

                Text(dateText)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Style "transparent" (sticker sur photo)

    private var transparentOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 30) {
                FloatingStat(label: "DISTANCE", value: String(format: "%.2f km", session.distanceKm), size: 64)
                FloatingStat(label: "ALLURE", value: session.paceFormatted, size: 46)
                FloatingStat(label: "DURÉE", value: session.durationFormatted, size: 46)
            }

            if !coordinates.isEmpty {
                RouteSilhouetteView(coordinates: coordinates)
                    .frame(height: 200)
                    .padding(.horizontal, 160)
                    .padding(.top, 40)
            }

            Image("FleetLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
                .shadow(color: .black.opacity(0.6), radius: 8)
                .padding(.top, 40)

            Spacer()
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
                colors: [AppTheme.accent.opacity(0.35), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 700
            )
        }
    }
}

private struct FloatingStat: View {
    let label: String
    let value: String
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(3)
                .shadow(color: .black.opacity(0.6), radius: 6)
            Text(value)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 10)
        }
    }
}

private struct ShareStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShareDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1, height: 40)
    }
}

private struct RouteSilhouetteView: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let points = normalizedPoints(in: geometry.size)
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            .shadow(color: AppTheme.accent.opacity(0.6), radius: 20)
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !coordinates.isEmpty else { return [] }

        let latitudes = coordinates.map(\.latitude)
        let averageLat = latitudes.reduce(0, +) / Double(latitudes.count)
        let latToY = 111_320.0
        let lonToX = 111_320.0 * cos(averageLat * .pi / 180)

        let projected = coordinates.map { coordinate -> CGPoint in
            CGPoint(x: coordinate.longitude * lonToX, y: coordinate.latitude * latToY)
        }

        let minX = projected.map(\.x).min() ?? 0
        let maxX = projected.map(\.x).max() ?? 0
        let minY = projected.map(\.y).min() ?? 0
        let maxY = projected.map(\.y).max() ?? 0

        let routeWidth = max(maxX - minX, 1)
        let routeHeight = max(maxY - minY, 1)

        let margin: CGFloat = 0.1
        let availableWidth = size.width * (1 - margin * 2)
        let availableHeight = size.height * (1 - margin * 2)

        let scale = min(availableWidth / routeWidth, availableHeight / routeHeight)

        let offsetX = (size.width - routeWidth * scale) / 2
        let offsetY = (size.height - routeHeight * scale) / 2

        return projected.map { point in
            CGPoint(
                x: (point.x - minX) * scale + offsetX,
                y: size.height - ((point.y - minY) * scale + offsetY)
            )
        }
    }
}

#Preview {
    ShareCardView(
        session: RunSession(
            id: UUID(),
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            distanceMeters: 8420,
            durationSeconds: 2500,
            averageHeartRate: 152,
            activeCalories: 480,
            elevationGainMeters: 45
        ),
        coordinates: [
            CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            CLLocationCoordinate2D(latitude: 48.8580, longitude: 2.3550),
            CLLocationCoordinate2D(latitude: 48.8600, longitude: 2.3530)
        ],
        transparent: true
    )
    .previewLayout(.fixed(width: 1080, height: 1080))
}
