import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var parentName = ""
    @AppStorage("childName") private var childName = ""
    @AppStorage("childPhoneNumber") private var childPhoneNumber = ""
    @AppStorage("childPhotoPath") private var childPhotoPath = ""
    // Same persisted key VoiceSetupView reads/writes, so both screens
    // share one source of truth instead of drifting out of sync.
    @AppStorage("voiceConsentGranted") private var consentGiven = false

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var status: String?

    private let familyId = FamilyContext.shared.familyId

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        photoView
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())

                        HStack(spacing: 16) {
                            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                                Text("Choose photo")
                            }
                            Button("Take photo") { showCamera = true }
                        }
                        .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section {
                TextField("Your name", text: $parentName)
                TextField("Child's name", text: $childName)
                TextField("Child's phone number", text: $childPhoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }

            Section {
                Toggle("I consent to my voice being used", isOn: $consentGiven)
                    .onChange(of: consentGiven) { _, newValue in
                        Task { try? await APIClient.shared.setVoiceConsent(familyId: familyId, granted: newValue) }
                    }
            }

            Section {
                Button(isSaving ? "Saving..." : "Save") {
                    save()
                }
                .disabled(isSaving)

                if let status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Profile")
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    savePhoto(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { image in
                showCamera = false
                if let image { savePhoto(image) }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var photoView: some View {
        if !childPhotoPath.isEmpty, let image = UIImage(contentsOfFile: childPhotoPath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle().fill(Color(.systemGray5))
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func savePhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Clean up the previous photo file, if any, now that it's replaced.
        if !childPhotoPath.isEmpty {
            try? FileManager.default.removeItem(atPath: childPhotoPath)
        }
        let fileURL = documents.appendingPathComponent("child_photo_\(UUID().uuidString).jpg")
        do {
            try data.write(to: fileURL)
            childPhotoPath = fileURL.path
        } catch {
            // Not critical enough to surface an error for — the photo
            // just won't update, existing profile fields are unaffected.
        }
    }

    private func save() {
        isSaving = true
        status = nil
        Task {
            do {
                try await APIClient.shared.setupFamily(
                    familyId: familyId,
                    parentName: parentName,
                    childName: childName,
                    language: storedLanguage,
                    childPhoneNumber: childPhoneNumber.trimmingCharacters(in: .whitespaces).isEmpty ? nil : childPhoneNumber
                )
                await MainActor.run {
                    status = "Saved."
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    status = "Couldn't save — check your connection and try again."
                    isSaving = false
                }
            }
        }
    }
}

/// Thin UIImagePickerController wrapper — SwiftUI has no native camera
/// capture view as of iOS 17. Kept local to this file since it's a small,
/// single-use component.
private struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
