import SwiftUI
import CoreLocation

/// Écran de partage façon Strava : carrousel d'aperçus (fond coloré / transparent / photo) + raccourcis.
struct ShareActivitySheet: View {
    let session: RunSession
    let coordinates: [CLLocationCoordinate2D]

    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var selectedPage: SharePage = .filled
    @State private var showSystemShareSheet = false
    @State private var systemShareImage: UIImage?
    @State private var savedConfirmation = false
    @State private var showPhotoPicker = false
    @State private var pickedPhoto: UIImage?
    @State private var compositeImage: UIImage?

    private let previewSize: CGFloat = 300

    private enum SharePage: Int, CaseIterable {
        case filled
        case transparent
        case photo
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TabView(selection: $selectedPage) {
                    ShareCardView(session: session, coordinates: routeCoordinates, transparent: false)
                        .scaleEffect(previewSize / 1080)
                        .frame(width: previewSize, height: previewSize)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .tag(SharePage.filled)

                    ShareCardView(session: session, coordinates: routeCoordinates, transparent: true)
                        .scaleEffect(previewSize / 1080)
                        .frame(width: previewSize, height: previewSize)
                        .background(CheckerboardBackground())
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .tag(SharePage.transparent)

                    photoPageContent
                        .tag(SharePage.photo)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: previewSize + 40)

                if savedConfirmation {
                    Text("Image enregistrée dans Photos")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                HStack(spacing: 28) {
                    ShareActionButton(icon: "camera.circle.fill", label: "Story\nInstagram", tint: .pink) {
                        shareToInstagram()
                    }
                    ShareActionButton(icon: "doc.on.doc.fill", label: "Copier") {
                        copyToClipboard()
                    }
                    ShareActionButton(icon: "square.and.arrow.down.fill", label: "Enregistrer") {
                        saveToPhotos()
                    }
                    ShareActionButton(icon: "ellipsis.circle.fill", label: "Plus") {
                        systemShareImage = currentImage()
                        showSystemShareSheet = true
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 12)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Partager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(AppTheme.accent)
                }
            }
            .task {
                // On refait la requête ici pour être sûr d'avoir le tracé, même si RunDetailView
                // n'avait pas encore fini sa propre requête au moment où la fenêtre s'est ouverte.
                if !coordinates.isEmpty {
                    routeCoordinates = coordinates
                } else {
                    routeCoordinates = await healthKitManager.fetchRoute(for: session)
                }
            }
            .onChange(of: routeCoordinates.count) { _, _ in
                // Si l'utilisateur a déjà choisi sa photo avant que le tracé ait fini de charger,
                // on régénère l'image composite maintenant qu'on a le tracé.
                if let pickedPhoto {
                    compositeImage = ManualShareCardRenderer.renderComposite(session: session, coordinates: routeCoordinates, backgroundImage: pickedPhoto)
                }
            }
            .sheet(isPresented: $showSystemShareSheet) {
                if let systemShareImage {
                    ShareSheet(items: [systemShareImage])
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker { image in
                    pickedPhoto = image
                    compositeImage = ManualShareCardRenderer.renderComposite(session: session, coordinates: routeCoordinates, backgroundImage: image)
                }
            }
        }
    }

    private var photoPageContent: some View {
        Group {
            if let compositeImage {
                Image(uiImage: compositeImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: previewSize, height: previewSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture {
                        showPhotoPicker = true
                    }
            } else {
                Button {
                    showPhotoPicker = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                        Text("Choisir une photo")
                            .font(.subheadline)
                    }
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: previewSize, height: previewSize)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func currentImage() -> UIImage? {
        switch selectedPage {
        case .filled:
            return ShareCardRenderer.render(session: session, coordinates: routeCoordinates, transparent: false)
        case .transparent:
            return ShareCardRenderer.render(session: session, coordinates: routeCoordinates, transparent: true)
        case .photo:
            return compositeImage
        }
    }

    private func shareToInstagram() {
        if selectedPage == .photo, let compositeImage {
            systemShareImage = compositeImage
            showSystemShareSheet = true
            return
        }
        guard let image = ShareCardRenderer.render(session: session, coordinates: routeCoordinates, transparent: true) else { return }
        if InstagramStorySharer.isInstagramInstalled {
            InstagramStorySharer.shareSticker(image)
        } else {
            systemShareImage = image
            showSystemShareSheet = true
        }
    }

    private func copyToClipboard() {
        guard let image = currentImage() else { return }
        UIPasteboard.general.image = image
    }

    private func saveToPhotos() {
        guard let image = currentImage() else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        savedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            savedConfirmation = false
        }
    }
}

private struct ShareActionButton: View {
    let icon: String
    let label: String
    var tint: Color = AppTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CheckerboardBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let tile: CGFloat = 20
            let columns = Int(geometry.size.width / tile) + 1
            let rows = Int(geometry.size.height / tile) + 1
            Canvas { context, size in
                for row in 0..<rows {
                    for column in 0..<columns {
                        if (row + column).isMultiple(of: 2) {
                            let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                            context.fill(Path(rect), with: .color(.white.opacity(0.08)))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ShareActivitySheet(
        session: RunSession(
            id: UUID(),
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            distanceMeters: 6000,
            durationSeconds: 3092,
            averageHeartRate: 152,
            activeCalories: 480,
            elevationGainMeters: 45
        ),
        coordinates: []
    )
    .environmentObject(HealthKitManager())
}
