import Foundation

/// Représente le fait qu'un utilisateur en suit un autre.
struct Follow: Identifiable, Codable {
    let id: String // format : "{followerId}_{followingId}"
    let followerId: String
    let followingId: String
    let createdAt: Date
}
