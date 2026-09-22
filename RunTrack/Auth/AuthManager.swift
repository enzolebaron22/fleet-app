import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userName: String = ""
    @Published var userPhotoURL: URL?
    @Published var memberSince: Date?
    @Published var isSigningIn: Bool = false
    @Published var errorMessage: String?

    // Champs publics utilisés pour les suggestions de profil et la recherche.
    @Published var city: String?
    @Published var averagePaceSecondsPerKm: Double?
    @Published var isMentor: Bool = false
    @Published var username: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isSignedIn = user != nil
                self?.userName = user?.displayName ?? ""
                self?.userPhotoURL = user?.photoURL
                if let uid = user?.uid {
                    await self?.fetchProfile(uid: uid)
                } else {
                    self?.memberSince = nil
                    self?.city = nil
                    self?.averagePaceSecondsPerKm = nil
                    self?.isMentor = false
                    self?.username = nil
                }
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func signInWithGoogle() {
        guard let rootViewController = Self.rootViewController() else {
            errorMessage = "Impossible de démarrer la connexion. Réessaie."
            return
        }

        isSigningIn = true
        errorMessage = nil

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                await self.handleSignInResult(result: result, error: error)
            }
        }
    }

    private func handleSignInResult(result: GIDSignInResult?, error: Error?) async {
        if let error {
            isSigningIn = false
            errorMessage = "Connexion impossible : \(error.localizedDescription)"
            return
        }

        guard let user = result?.user, let idToken = user.idToken?.tokenString else {
            isSigningIn = false
            errorMessage = "Connexion impossible. Réessaie."
            return
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            await saveProfileIfNeeded(authResult: authResult)
        } catch {
            errorMessage = "Connexion impossible : \(error.localizedDescription)"
        }

        isSigningIn = false
    }

    private func saveProfileIfNeeded(authResult: AuthDataResult) async {
        let userRef = Firestore.firestore().collection("users").document(authResult.user.uid)
        do {
            let snapshot = try await userRef.getDocument()
            if !snapshot.exists {
                try await userRef.setData([
                    "name": authResult.user.displayName ?? "",
                    "email": authResult.user.email ?? "",
                    "photoURL": authResult.user.photoURL?.absoluteString ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "isMentor": false
                ])
            }
            await fetchProfile(uid: authResult.user.uid)
        } catch {
            // Non bloquant : la connexion a réussi même si l'enregistrement du profil échoue.
        }
    }

    /// Récupère les infos stockées dans Firestore (notamment la date d'inscription et les infos publiques).
    func fetchProfile(uid: String) async {
        let userRef = Firestore.firestore().collection("users").document(uid)
        do {
            let snapshot = try await userRef.getDocument()
            let data = snapshot.data()
            if let timestamp = data?["createdAt"] as? Timestamp {
                memberSince = timestamp.dateValue()
            }
            city = data?["city"] as? String
            averagePaceSecondsPerKm = data?["averagePaceSecondsPerKm"] as? Double
            isMentor = data?["isMentor"] as? Bool ?? false
            username = data?["username"] as? String
        } catch {
            // Non bloquant : on affichera simplement le profil sans ces infos.
        }
    }

    /// Met à jour les infos publiques du profil.
    func updatePublicProfile(city: String? = nil, averagePaceSecondsPerKm: Double? = nil, isMentor: Bool? = nil) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var updates: [String: Any] = [:]
        if let city {
            updates["city"] = city
        }
        if let averagePaceSecondsPerKm {
            updates["averagePaceSecondsPerKm"] = averagePaceSecondsPerKm
        }
        if let isMentor {
            updates["isMentor"] = isMentor
        }
        guard !updates.isEmpty else { return }

        do {
            try await Firestore.firestore().collection("users").document(uid).setData(updates, merge: true)
            if let city { self.city = city }
            if let averagePaceSecondsPerKm { self.averagePaceSecondsPerKm = averagePaceSecondsPerKm }
            if let isMentor { self.isMentor = isMentor }
        } catch {
            // Non bloquant.
        }
    }

    /// Vérifie si un pseudo est déjà pris.
    func isUsernameAvailable(_ candidate: String) async -> Bool {
        let normalized = candidate.lowercased()
        let doc = try? await Firestore.firestore().collection("usernames").document(normalized).getDocument()
        return !(doc?.exists ?? false)
    }

    /// Définit le pseudo de l'utilisateur courant (une seule fois, de façon unique et définitive pour l'instant).
    func setUsername(_ candidate: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let normalized = candidate.lowercased()
        let db = Firestore.firestore()
        let usernameRef = db.collection("usernames").document(normalized)
        let userRef = db.collection("users").document(uid)

        try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(usernameRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            if snapshot.exists {
                errorPointer?.pointee = NSError(
                    domain: "Fleet",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Ce pseudo est déjà pris."]
                )
                return nil
            }
            transaction.setData(["uid": uid], forDocument: usernameRef)
            transaction.setData(["username": normalized], forDocument: userRef, merge: true)
            return nil
        }
        self.username = normalized
    }

    /// Cherche un utilisateur par son pseudo et retourne son uid s'il existe.
    func findUser(byUsername candidate: String) async -> String? {
        let normalized = candidate.lowercased()
        let doc = try? await Firestore.firestore().collection("usernames").document(normalized).getDocument()
        return doc?.data()?["uid"] as? String
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            errorMessage = "Erreur lors de la déconnexion."
        }
    }

    private static func rootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return root
    }
}
