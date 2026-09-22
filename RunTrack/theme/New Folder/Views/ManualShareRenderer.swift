import UIKit
import CoreLocation

/// Dessine les cartes de partage nous-mêmes avec Core Graphics (pas SwiftUI), pour un contrôle total du rendu.
enum ManualShareCardRenderer {

    /// Stats qui flottent sur un fond transparent (sticker).
    static func renderTransparent(session: RunSession, coordinates: [CLLocationCoordinate2D]) -> UIImage? {
        let canvasSize = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { rendererContext in
            drawStatsAndLogo(session: session, coordinates: coordinates, canvasSize: canvasSize, context: rendererContext.cgContext)
        }
    }

    /// Stats collées sur une photo choisie par l'utilisateur (image complète, aucune transparence nécessaire).
    static func renderComposite(session: RunSession, coordinates: [CLLocationCoordinate2D], backgroundImage: UIImage) -> UIImage? {
        let canvasSize = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext

            drawImageAspectFill(backgroundImage, in: CGRect(origin: .zero, size: canvasSize))

            // Voile sombre léger pour que le texte reste lisible sur n'importe quelle photo.
            context.setFillColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            context.fill(CGRect(origin: .zero, size: canvasSize))

            drawStatsAndLogo(session: session, coordinates: coordinates, canvasSize: canvasSize, context: context)
        }
    }

    private static func drawImageAspectFill(_ image: UIImage, in rect: CGRect) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: rect.midX - scaledSize.width / 2, y: rect.midY - scaledSize.height / 2)
        image.draw(in: CGRect(origin: origin, size: scaledSize))
    }

    private static func drawStatsAndLogo(session: RunSession, coordinates: [CLLocationCoordinate2D], canvasSize: CGSize, context: CGContext) {
        let stats: [(label: String, value: String, valueFontSize: CGFloat)] = [
            ("DISTANCE", String(format: "%.2f km", session.distanceKm), 64),
            ("ALLURE", session.paceFormatted, 46),
            ("DURÉE", session.durationFormatted, 46)
        ]

        let hasRoute = !coordinates.isEmpty
        let routeHeight: CGFloat = hasRoute ? 200 : 0
        let routeTopGap: CGFloat = hasRoute ? 40 : 0
        let logoHeight: CGFloat = 30
        let logoTopGap: CGFloat = 40

        let labelFontSize: CGFloat = 20
        let labelValueGap: CGFloat = 6
        let statBlockGap: CGFloat = 30

        var statsBlockHeight: CGFloat = 0
        for (index, stat) in stats.enumerated() {
            statsBlockHeight += labelFontSize + labelValueGap + stat.valueFontSize
            if index < stats.count - 1 {
                statsBlockHeight += statBlockGap
            }
        }

        let totalHeight = statsBlockHeight + routeTopGap + routeHeight + logoTopGap + logoHeight
        var y = (canvasSize.height - totalHeight) / 2

        for stat in stats {
            y += drawCenteredLine(stat.label, fontSize: labelFontSize, weight: .semibold, color: UIColor.white.withAlphaComponent(0.8), tracking: 3, canvasWidth: canvasSize.width, y: y)
            y += labelValueGap
            y += drawCenteredLine(stat.value, fontSize: stat.valueFontSize, weight: .heavy, color: .white, rounded: true, canvasWidth: canvasSize.width, y: y)
            y += statBlockGap
        }
        y -= statBlockGap

        if hasRoute {
            y += routeTopGap
            let routeRect = CGRect(x: 160, y: y, width: canvasSize.width - 320, height: routeHeight)
            drawRouteSilhouette(coordinates: coordinates, in: routeRect, context: context)
            y += routeHeight
        }

        y += logoTopGap
        if let logo = UIImage(named: "FleetLogo") {
            let logoWidth = logoHeight * (logo.size.width / logo.size.height)
            let logoRect = CGRect(x: (canvasSize.width - logoWidth) / 2, y: y, width: logoWidth, height: logoHeight)
            context.saveGState()
            context.setShadow(offset: .zero, blur: 3, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            logo.draw(in: logoRect)
            context.restoreGState()
        }
    }

    @discardableResult
    private static func drawCenteredLine(_ text: String, fontSize: CGFloat, weight: UIFont.Weight, color: UIColor, tracking: CGFloat = 0, rounded: Bool = false, canvasWidth: CGFloat, y: CGFloat) -> CGFloat {
        var font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        if rounded, let descriptor = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: fontSize)
        }

        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = CGSize(width: 0, height: 1)

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .shadow: shadow
        ]
        if tracking > 0 {
            attributes[.kern] = tracking
        }

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let origin = CGPoint(x: (canvasWidth - textSize.width) / 2, y: y)
        attributedString.draw(at: origin)
        return textSize.height
    }

    private static func drawRouteSilhouette(coordinates: [CLLocationCoordinate2D], in rect: CGRect, context: CGContext) {
        let localPoints = routePoints(for: coordinates, in: rect.size)
        guard let first = localPoints.first else { return }

        let path = UIBezierPath()
        path.move(to: CGPoint(x: first.x + rect.minX, y: first.y + rect.minY))
        for point in localPoints.dropFirst() {
            path.addLine(to: CGPoint(x: point.x + rect.minX, y: point.y + rect.minY))
        }
        path.lineWidth = 8
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        context.saveGState()
        context.setShadow(offset: .zero, blur: 4, color: UIColor.black.withAlphaComponent(0.4).cgColor)
        UIColor.white.setStroke()
        path.stroke()
        context.restoreGState()
    }

    private static func routePoints(for coordinates: [CLLocationCoordinate2D], in size: CGSize) -> [CGPoint] {
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

        let scale = min(size.width / routeWidth, size.height / routeHeight)
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
