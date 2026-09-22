import Foundation
import Combine
import FirebaseFirestore

/// Gère les données sociales (follow, encouragements) dans Firestore.
@MainActor
final class SocialManager: ObservableObject {
    private let db = Firestore.firestore()

    func follow(currentUserId: String, targetUserId: String) async throws {
        let followId = "\(currentUserId)_\(targetUserId)"
        try await db.collection("follows").document(followId).setData([
            "followerId": currentUserId,
            "followingId": targetUserId,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func unfollow(currentUserId: String, targetUserId: String) async throws {
        let followId = "\(currentUserId)_\(targetUserId)"
        try await db.collection("follows").document(followId).delete()
    }

    func isFollowing(currentUserId: String, targetUserId: String) async -> Bool {
        let followId = "\(currentUserId)_\(targetUserId)"
        let snapshot = try? await db.collection("follows").document(followId).getDocument()
        return snapshot?.exists ?? false
    }

    func fetchFollowing(currentUserId: String) async -> [String] {
        do {
            let snapshot = try await db.collection("follows")
                .whereField("followerId", isEqualTo: currentUserId)
                .getDocuments()
            return snapshot.documents.compactMap { $0.data()["followingId"] as? String }
        } catch {
            return []
        }
    }

    func sendEncouragement(from currentUserId: String, to targetUserId: String, sessionId: String? = nil) async throws {
        var data: [String: Any] = [
            "fromUserId": currentUserId,
            "toUserId": targetUserId,
            "createdAt": Timestamp(date: Date())
        ]
        if let sessionId {
            data["sessionId"] = sessionId
        }
        try await db.collection("encouragements").addDocument(data: data)
    }

    func fetchEncouragementsReceived(userId: String) async -> [Encouragement] {
        do {
            let snapshot = try await db.collection("encouragements")
                .whereField("toUserId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            return snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let fromUserId = data["fromUserId"] as? String,
                      let toUserId = data["toUserId"] as? String,
                      let timestamp = data["createdAt"] as? Timestamp else { return nil }
                return Encouragement(
                    id: doc.documentID,
                    fromUserId: fromUserId,
                    toUserId: toUserId,
                    sessionId: data["sessionId"] as? String,
                    createdAt: timestamp.dateValue()
                )
            }
        } catch {
            return []
        }
    }

    /// Récupère le profil public d'un utilisateur à partir de son uid.
    func fetchPublicProfile(uid: String) async -> PublicProfile? {
        guard let snapshot = try? await db.collection("users").document(uid).getDocument(),
              let data = snapshot.data() else { return nil }
        let name = data["name"] as? String ?? ""
        let username = data["username"] as? String
        let photoURLString = data["photoURL"] as? String
        let isMentor = data["isMentor"] as? Bool ?? false
        return PublicProfile(
            id: uid,
            name: name,
            username: username,
            photoURL: (photoURLString?.isEmpty == false) ? URL(string: photoURLString!) : nil,
            isMentor: isMentor
        )
    }
}
