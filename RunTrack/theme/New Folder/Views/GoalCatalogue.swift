import Foundation

/// Un objectif possible que l'utilisateur peut choisir pour personnaliser son expérience.
struct GoalOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}

enum GoalCatalog {
    static let all: [GoalOption] = [
        GoalOption(id: "restart", title: "Reprendre une activité", subtitle: "Se remettre en mouvement, à mon rythme", icon: "figure.walk"),
        GoalOption(id: "health", title: "Perdre du poids / être en forme", subtitle: "Prendre soin de ma santé", icon: "heart.fill"),
        GoalOption(id: "first_run", title: "Courir mon premier 5 km", subtitle: "Un premier vrai objectif de course", icon: "flag.checkered"),
        GoalOption(id: "consistency", title: "Rester régulier", subtitle: "Créer une habitude durable", icon: "calendar.badge.clock"),
        GoalOption(id: "race", title: "Préparer une course", subtitle: "10 km, semi, marathon...", icon: "trophy.fill"),
        GoalOption(id: "fun", title: "Juste pour le plaisir", subtitle: "Sans pression, sans objectif précis", icon: "sparkles")
    ]

    static func option(for id: String?) -> GoalOption? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}
