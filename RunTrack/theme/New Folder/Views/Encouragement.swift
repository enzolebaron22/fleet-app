import Foundation

/// Un encouragement envoyé par un utilisateur à un autre (jamais de comparaison de perf).
struct Encouragement: Identifiable, Codable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let sessionId: String?
    let createdAt: Date
}
