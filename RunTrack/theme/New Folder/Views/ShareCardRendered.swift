import SwiftUI
import CoreLocation
import UIKit

/// Transforme une ShareCardView en image exportable (pour le partage).
enum ShareCardRenderer {
    static func render(session: RunSession, coordinates: [CLLocationCoordinate2D], transparent: Bool = false) -> UIImage? {
        if transparent {
            return ManualShareCardRenderer.renderTransparent(session: session, coordinates: coordinates)
        }
        return renderFilled(session: session, coordinates: coordinates)
    }

    private static func renderFilled(session: RunSession, coordinates: [CLLocationCoordinate2D]) -> UIImage? {
        let card = ShareCardView(session: session, coordinates: coordinates, transparent: false)
        let controller = UIHostingController(rootView: card)
        controller.overrideUserInterfaceStyle = .dark

        let targetSize = CGSize(width: 1080, height: 1080)
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { _ in
            controller.view.drawHierarchy(in: CGRect(origin: .zero, size: targetSize), afterScreenUpdates: true)
        }
    }
}
