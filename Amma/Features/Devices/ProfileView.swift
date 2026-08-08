import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var parentName = ""
    @AppStorage("childName") private var childName = ""
    @AppStorage("childPhoneNumber") private var childPhoneNumber = ""
    @AppStorage("parentPhotoPath") private var parentPhotoPath = ""
    @AppStorage("childPhotoPath") private var childPhotoPath = ""
    // Same persisted key VoiceSetupView reads/writes, so both screens
    // share one source of truth instead of drifting out of sync.
    @AppStorage("voiceConsentGranted") private var consentGiven = false

    @State private var isSaving = false
    @State private var status: String?

    private let familyId = FamilyContext.shared.familyId

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotoPickerField(title: "You", placeholderIcon: "person.fill", photoPath: $parentPhotoPath)
                    Spacer()
                    PhotoPickerField(title: "Child", placeholderIcon: "face.smiling", photoPath: $childPhotoPath)
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
                HomeScreenPictureField()
            } header: {
                Text("Home screen")
            } footer: {
                Text("Shown on the Talk screen when you open the app — pick one of the defaults or use your own photo.")
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

/// One photo slot (avatar + "Choose photo"/"Take photo" + persistence to
/// Documents). Used twice in ProfileView — once for the parent's own
/// picture, once for the child's — each bound to its own @AppStorage path
/// so the two never clobber each other.
private struct PhotoPickerField: View {
    let title: String
    let placeholderIcon: String
    @Binding var photoPath: String

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 8) {
            photoView
                .frame(width: 96, height: 96)
                .clipShape(Circle())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    Text("Choose photo")
                }
                // No camera on the Simulator, and some devices/
                // configurations (camera restricted by MDM or Screen
                // Time, iPads without one) don't have it either —
                // UIImagePickerController crashes with an uncaught
                // NSInvalidArgumentException if you set .camera as the
                // source type when it isn't available, so hide the
                // button instead.
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take photo") { showCamera = true }
                }
            }
            .font(.caption)
        }
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
        if !photoPath.isEmpty, let image = UIImage(contentsOfFile: photoPath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle().fill(Color(.systemGray5))
                Image(systemName: placeholderIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func savePhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Clean up the previous photo file, if any, now that it's replaced.
        if !photoPath.isEmpty {
            try? FileManager.default.removeItem(atPath: photoPath)
        }
        let fileURL = documents.appendingPathComponent("photo_\(UUID().uuidString).jpg")
        do {
            try data.write(to: fileURL)
            photoPath = fileURL.path
        } catch {
            // Not critical enough to surface an error for — the photo
            // just won't update, existing profile fields are unaffected.
        }
    }
}

/// Editor for the Talk screen's welcome picture: a row of curated preset
/// icons plus the same "Choose photo"/"Take photo" pattern as the You/
/// Child fields above, except a custom photo and a preset are mutually
/// exclusive here — picking one clears the other. HomeScreenPictureView
/// (shared with TalkView) renders whichever is currently set.
private struct HomeScreenPictureField: View {
    @AppStorage("homeScreenPhotoPath") private var photoPath = ""
    @AppStorage("homeScreenPreset") private var presetRaw = ""

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 16) {
            HomeScreenPictureView(size: 100)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HomeScreenPreset.allCases) { preset in
                        Button {
                            selectPreset(preset)
                        } label: {
                            ZStack {
                                Circle().fill(preset.tint.opacity(0.15))
                                Image(systemName: preset.systemImage)
                                    .foregroundStyle(preset.tint)
                            }
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(preset.tint, lineWidth: presetRaw == preset.rawValue ? 2.5 : 0)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }

            HStack(spacing: 16) {
                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    Text("Choose photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take photo") { showCamera = true }
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    saveCustomPhoto(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { image in
                showCamera = false
                if let image { saveCustomPhoto(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func selectPreset(_ preset: HomeScreenPreset) {
        if !photoPath.isEmpty {
            try? FileManager.default.removeItem(atPath: photoPath)
            photoPath = ""
        }
        presetRaw = preset.rawValue
    }

    private func saveCustomPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if !photoPath.isEmpty {
            try? FileManager.default.removeItem(atPath: photoPath)
        }
        let fileURL = documents.appendingPathComponent("home_screen_\(UUID().uuidString).jpg")
        do {
            try data.write(to: fileURL)
            photoPath = fileURL.path
            presetRaw = ""
        } catch {
            // Not critical enough to surface an error for — the picture
            // just won't update, existing profile fields are unaffected.
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
