import Foundation

/// Version publique et allégée d'un profil, pour afficher quelqu'un d'autre que soi-même.
struct PublicProfile: Identifiable {
    let id: String // uid
    let name: String
    let username: String?
    let photoURL: URL?
    let isMentor: Bool
}
