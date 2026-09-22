import SwiftUI
import UIKit

/// Habillage SwiftUI du menu de partage natif d'iOS (Messages, Instagram, Photos...).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
