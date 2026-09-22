import UIKit

/// Envoie une image directement dans l'éditeur de story Instagram (sticker natif, transparence garantie).
enum InstagramStorySharer {
    static var isInstagramInstalled: Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Ouvre Instagram avec l'image posée en sticker sur une nouvelle story.
    static func shareSticker(_ image: UIImage) {
        guard let stickerData = image.pngData(),
              let url = URL(string: "instagram-stories://share") else { return }

        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.stickerImage": stickerData,
            "com.instagram.sharedSticker.backgroundTopColor": "#291509",
            "com.instagram.sharedSticker.backgroundBottomColor": "#0A0A0A"
        ]

        UIPasteboard.general.setItems(
            [pasteboardItems],
            options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
        )

        UIApplication.shared.open(url)
    }
}
