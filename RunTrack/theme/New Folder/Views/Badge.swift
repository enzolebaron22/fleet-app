import Foundation

/// Contexte utilisé pour déterminer si un badge est débloqué.
struct BadgeContext {
    let sessions: [RunSession]
    let currentStreak: Int
    let longestStreak: Int
}

struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tip: String
    let iconName: String
    let isUnlocked: (BadgeContext) -> Bool
}

/// Le catalogue de tous les badges de l'app, basés sur la régularité, jamais sur la performance brute.
enum BadgeCatalog {
    static let all: [Badge] = [
        Badge(
            id: "first_run",
            title: "Premier pas",
            detail: "Ta première course enregistrée.",
            tip: "Le plus dur est fait : tu as commencé. La régularité compte plus que la vitesse.",
            iconName: "flag.checkered",
            isUnlocked: { ctx in !ctx.sessions.isEmpty }
        ),
        Badge(
            id: "streak_2",
            title: "Sur la lancée",
            detail: "2 semaines de suite avec au moins une course.",
            tip: "Essaie de courir toujours au même moment de la semaine, ça aide à créer l'habitude.",
            iconName: "flame",
            isUnlocked: { ctx in ctx.longestStreak >= 2 }
        ),
        Badge(
            id: "streak_4",
            title: "Habitude installée",
            detail: "4 semaines de suite avec au moins une course.",
            tip: "À ce stade, la régularité devient un vrai réflexe. Varie les allures pour progresser sans te lasser.",
            iconName: "flame.fill",
            isUnlocked: { ctx in ctx.longestStreak >= 4 }
        ),
        Badge(
            id: "streak_8",
            title: "Ancré dans la durée",
            detail: "8 semaines de suite avec au moins une course.",
            tip: "Deux mois de régularité : écoute ton corps et ajoute un jour de repos si besoin.",
            iconName: "medal.fill",
            isUnlocked: { ctx in ctx.longestStreak >= 8 }
        ),
        Badge(
            id: "ten_runs",
            title: "Explorateur",
            detail: "10 courses enregistrées au total.",
            tip: "Chaque sortie compte, même les courtes. Continue à explorer de nouveaux parcours.",
            iconName: "map.fill",
            isUnlocked: { ctx in ctx.sessions.count >= 10 }
        ),
        Badge(
            id: "fifty_runs",
            title: "Coureur confirmé",
            detail: "50 courses enregistrées au total.",
            tip: "Tu as l'expérience maintenant. Pense à aider les autres coureurs autour de toi.",
            iconName: "star.circle.fill",
            isUnlocked: { ctx in ctx.sessions.count >= 50 }
        ),
        Badge(
            id: "first_10k",
            title: "Longue distance",
            detail: "Une course de 10 km ou plus.",
            tip: "Bravo pour cette distance ! Pense à bien t'hydrater et à récupérer après une longue sortie.",
            iconName: "figure.run",
            isUnlocked: { ctx in ctx.sessions.contains { $0.distanceKm >= 10 } }
        )
    ]
}
