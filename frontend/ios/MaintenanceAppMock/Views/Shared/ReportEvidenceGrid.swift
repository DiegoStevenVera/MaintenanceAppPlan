import SwiftUI
import UIKit

struct CameraPhotoPicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPhotoPicker

        init(parent: CameraPhotoPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct EditableReportEvidenceGrid: View {
    @Binding var evidence: [APIReportEvidenceWrite]

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 280), spacing: AppSpacing.md)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.md) {
            ForEach(evidence) { item in
                ReportEvidenceImageTile(
                    id: item.id,
                    title: evidenceTitle(item.title, fallback: item.originalFileName),
                    mediaType: item.mediaType,
                    contentBase64: item.contentBase64,
                    attachmentID: item.attachmentID
                ) {
                    withAnimation(.snappy) {
                        evidence.removeAll { $0.id == item.id }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StoredReportEvidenceGrid: View {
    let evidence: [APIStoredEvidence]

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 280), spacing: AppSpacing.md)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.md) {
            ForEach(evidence) { item in
                ReportEvidenceImageTile(
                    id: item.id,
                    title: evidenceTitle(
                        item.title,
                        fallback: evidenceTitle(
                            item.originalFileName,
                            fallback: "Evidencia"
                        )
                    ),
                    mediaType: item.mediaType,
                    contentBase64: nil,
                    attachmentID: item.id,
                    onDelete: nil
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func evidenceTitle(_ value: String?, fallback: String) -> String {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return fallback
    }
    return value
}

private struct ReportEvidenceImageTile: View {
    @EnvironmentObject private var session: SessionStore

    let id: String
    let title: String
    let mediaType: String?
    let contentBase64: String?
    let attachmentID: String?
    let onDelete: (() -> Void)?

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var didFail = false
    @State private var isPresentingImage = false
    @State private var reloadID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button {
                guard loadedImage != nil else {
                    reloadID = UUID()
                    return
                }
                isPresentingImage = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))

                    if let loadedImage {
                        Image(uiImage: loadedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .clipped()
                    } else if isLoading {
                        ProgressView()
                    } else {
                        VStack(spacing: AppSpacing.sm) {
                            Image(
                                systemName: didFail
                                    ? "arrow.clockwise.circle"
                                    : "photo"
                            )
                            .font(.largeTitle)
                            Text(didFail ? "Reintentar" : "Sin vista previa")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if loadedImage != nil {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.55), in: Circle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(8)
                    }
                }
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Eliminar \(title)")
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .task(id: reloadID) {
            await loadImage()
        }
        .sheet(isPresented: $isPresentingImage) {
            NavigationStack {
                Group {
                    if let loadedImage {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: loadedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, minHeight: 420)
                                .padding()
                        }
                    }
                }
                .background(Color.black)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Cerrar") {
                            isPresentingImage = false
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func loadImage() async {
        if let contentBase64,
           let localData = Data(base64Encoded: contentBase64),
           let localImage = UIImage(data: localData) {
            loadedImage = localImage
            didFail = false
            return
        }

        guard mediaType?.hasPrefix("image/") != false,
              let attachmentID,
              !attachmentID.isEmpty,
              let baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") else {
            didFail = true
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await session.withValidAccessToken { token in
                try await APIClient(baseURLString: baseURL).getData(
                    "api/v1/attachments/\(attachmentID)/content",
                    bearerToken: token
                )
            }
            guard let remoteImage = UIImage(data: data) else {
                didFail = true
                return
            }
            loadedImage = remoteImage
            didFail = false
        } catch {
            didFail = true
        }
    }
}
