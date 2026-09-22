import SwiftUI

/// Palette et styles communs de l'app, pour une apparence cohérente sur tous les écrans.
enum AppTheme {
    // MARK: - Couleurs

    /// Fond principal (gris charbon, plus doux qu'un noir pur pour moins fatiguer les yeux).
    static let background = Color(red: 0.11, green: 0.11, blue: 0.12)

    /// Fond des cartes, légèrement plus clair que le fond principal.
    static let card = Color(red: 0.17, green: 0.17, blue: 0.18)

    /// Accent principal de l'app.
    static let accent = Color(red: 1.0, green: 0.45, blue: 0.15)

    /// Texte secondaire (labels, sous-titres).
    static let textSecondary = Color(red: 0.65, green: 0.65, blue: 0.67)

    /// Séparateurs discrets.
    static let separator = Color(red: 0.2, green: 0.2, blue: 0.21)

    // MARK: - Métriques communes

    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
}

/// Style de carte réutilisable : fond, coins arrondis, léger padding.
struct AppCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

extension View {
    /// Applique le style de carte standard de l'app (fond, coins arrondis, padding).
    func appCard() -> some View {
        modifier(AppCardStyle())
    }

    /// Applique le fond sombre standard de l'app à un écran (à poser sur le ScrollView/List racine).
    func appBackground() -> some View {
        self.background(AppTheme.background.ignoresSafeArea())
    }
}
