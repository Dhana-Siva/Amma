import SwiftUI
import PhotosUI
import UIKit

/// Which picture slot a photo-library or camera pick currently in
/// progress is destined for. Centralizing this at ProfileView — rather
/// than each field owning its own PhotosPicker/camera state — means only
/// one picker of each kind ever exists in the view tree at a time.
/// Reported live on a real iOS 17.5 device (not reproducible on the
/// Simulator): with three separate PhotosPicker instances mounted
/// simultaneously (You/Child/Home screen), picking a photo in any one of
/// them re-presented the picker sheet again immediately — three times in
/// a row, matching the instance count exactly. Per-instance `.id()`s
/// weren't enough to stop it; the fix is not having three live at once.
private enum PhotoTarget: Identifiable {
    case parent, child, homeScreen
    var id: Self { self }
}

struct ProfileView: View {
    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var parentName = ""
    @AppStorage("parentRelation") private var parentRelation = ""
    @AppStorage("childName") private var childName = ""
    @AppStorage("childPhoneNumber") private var childPhoneNumber = ""
    @AppStorage("parentPhotoPath") private var parentPhotoPath = ""
    @AppStorage("childPhotoPath") private var childPhotoPath = ""
    @AppStorage("homeScreenPhotoPath") private var homeScreenPhotoPath = ""
    @AppStorage("homeScreenPreset") private var homeScreenPreset = ""
    // Same persisted key VoiceSetupView reads/writes, so both screens
    // share one source of truth instead of drifting out of sync.
    @AppStorage("voiceConsentGranted") private var consentGiven = false

    @State private var isSaving = false
    @State private var status: String?

    // The one shared photo-picking state for the whole screen — see
    // PhotoTarget's doc comment for why this isn't per-field.
    // isPhotosPickerPresented is a real stored Bool, not a computed
    // Binding over photosPickerTarget — an inline Binding(get:set:) here
    // is recreated every body evaluation, which broke the picker's
    // internal auto-dismiss-on-select behavior (selecting a photo left
    // the sheet open with just a checkmark, no way to confirm) even
    // though presentation itself worked fine.
    @State private var photosPickerTarget: PhotoTarget?
    @State private var isPhotosPickerPresented = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var cameraTarget: PhotoTarget?

    private let familyId = FamilyContext.shared.familyId

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotoPickerField(
                        title: "You",
                        placeholderIcon: "person.fill",
                        photoPath: parentPhotoPath,
                        onChoosePhoto: { beginPhotoPicker(for: .parent) },
                        onTakePhoto: { cameraTarget = .parent }
                    )
                    Spacer()
                    PhotoPickerField(
                        title: "Child",
                        placeholderIcon: "face.smiling",
                        photoPath: childPhotoPath,
                        onChoosePhoto: { beginPhotoPicker(for: .child) },
                        onTakePhoto: { cameraTarget = .child }
                    )
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
            } footer: {
                Text("Nothing here appears in the Talk greeting — that uses how your child addresses you, set below.")
            }

            Section {
                TextField("How your child addresses you (e.g. Amma, Mom)", text: $parentRelation)
            } header: {
                Text("Relation")
            } footer: {
                Text("Used for the greeting on Talk — \"Good morning, \(parentRelation.trimmingCharacters(in: .whitespaces).isEmpty ? "Amma" : parentRelation)!\" instead of your name.")
            }

            Section {
                AvatarPickerField()
            } header: {
                Text("Avatar")
            } footer: {
                Text("Shown next to the name at the top of Talk — pick the real photo or a friendly default.")
            }

            Section {
                HomeScreenPictureField(
                    onChoosePhoto: { beginPhotoPicker(for: .homeScreen) },
                    onTakePhoto: { cameraTarget = .homeScreen }
                )
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
        .photosPicker(
            isPresented: $isPhotosPickerPresented,
            selection: $photosPickerItem,
            matching: .images
        )
        .onChange(of: photosPickerItem) { _, newItem in
            guard let target = photosPickerTarget else { return }
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { applyPhoto(image, to: target) }
                }
                await MainActor.run {
                    photosPickerItem = nil
                    photosPickerTarget = nil
                }
            }
        }
        .fullScreenCover(item: $cameraTarget) { target in
            CameraCapture { image in
                if let image { applyPhoto(image, to: target) }
                cameraTarget = nil
            }
            .ignoresSafeArea()
        }
    }

    private func beginPhotoPicker(for target: PhotoTarget) {
        photosPickerTarget = target
        isPhotosPickerPresented = true
    }

    private func applyPhoto(_ image: UIImage, to target: PhotoTarget) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        func write(replacing existingPath: String, prefix: String) -> String? {
            if !existingPath.isEmpty {
                try? FileManager.default.removeItem(atPath: existingPath)
            }
            let fileURL = documents.appendingPathComponent("\(prefix)_\(UUID().uuidString).jpg")
            do {
                try data.write(to: fileURL)
                return fileURL.path
            } catch {
                // Not critical enough to surface an error for — the
                // picture just won't update, existing fields are
                // unaffected.
                return nil
            }
        }

        switch target {
        case .parent:
            if let path = write(replacing: parentPhotoPath, prefix: "photo") { parentPhotoPath = path }
        case .child:
            if let path = write(replacing: childPhotoPath, prefix: "photo") { childPhotoPath = path }
        case .homeScreen:
            if let path = write(replacing: homeScreenPhotoPath, prefix: "home_screen") {
                homeScreenPhotoPath = path
                homeScreenPreset = ""
            }
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

/// One photo slot's display + trigger buttons (avatar preview, "Choose
/// photo"/"Take photo"). Purely presentational — actual picking is owned
/// by ProfileView (a single shared PhotosPicker/camera for the whole
/// screen; see PhotoTarget's doc comment for why).
private struct PhotoPickerField: View {
    let title: String
    let placeholderIcon: String
    let photoPath: String
    let onChoosePhoto: () -> Void
    let onTakePhoto: (() -> Void)?

    init(title: String, placeholderIcon: String, photoPath: String, onChoosePhoto: @escaping () -> Void, onTakePhoto: @escaping () -> Void) {
        self.title = title
        self.placeholderIcon = placeholderIcon
        self.photoPath = photoPath
        self.onChoosePhoto = onChoosePhoto
        // No camera on the Simulator, and some devices/configurations
        // (camera restricted by MDM or Screen Time, iPads without one)
        // don't have it either — UIImagePickerController crashes with an
        // uncaught NSInvalidArgumentException if you set .camera as the
        // source type when it isn't available, so hide the button
        // instead.
        self.onTakePhoto = UIImagePickerController.isSourceTypeAvailable(.camera) ? onTakePhoto : nil
    }

    var body: some View {
        VStack(spacing: 8) {
            photoView
                .frame(width: 96, height: 96)
                .clipShape(Circle())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Button(action: onChoosePhoto) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)

                if let onTakePhoto {
                    Button(action: onTakePhoto) {
                        Label("Take photo", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .controlSize(.small)
                }
            }
            .font(.caption)
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
}

/// Editor for the small avatar shown next to the child's name at the top
/// of Talk: a "Son"/"Child" tile using the real photo already set above,
/// plus a row of friendly character presets as an alternative — for a
/// parent who hasn't uploaded (or doesn't want to show) a real photo
/// there. Exactly one is active; AvatarView (shared with TalkView)
/// renders whichever it is. No photo picking of its own, so unaffected
/// by the shared-picker refactor above.
private struct AvatarPickerField: View {
    @AppStorage("childName") private var childName = ""
    @AppStorage("childPhotoPath") private var childPhotoPath = ""
    @AppStorage("avatarUsesChildPhoto") private var usesChildPhoto = true
    @AppStorage("avatarPreset") private var presetRaw = ""

    var body: some View {
        VStack(spacing: 16) {
            AvatarView(size: 90)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button {
                        usesChildPhoto = true
                    } label: {
                        VStack(spacing: 4) {
                            childPhotoThumbnail
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(.blue, lineWidth: usesChildPhoto ? 2.5 : 0)
                                )
                            Text(childName.isEmpty ? "Child" : childName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(AvatarPreset.allCases) { preset in
                        Button {
                            usesChildPhoto = false
                            presetRaw = preset.rawValue
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle().fill(preset.tint.opacity(0.18))
                                    Image(systemName: preset.systemImage)
                                        .foregroundStyle(preset.tint)
                                }
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle().stroke(preset.tint, lineWidth: (!usesChildPhoto && presetRaw == preset.rawValue) ? 2.5 : 0)
                                )
                                Text(preset.title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var childPhotoThumbnail: some View {
        if !childPhotoPath.isEmpty, let image = UIImage(contentsOfFile: childPhotoPath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle().fill(Color(.systemGray5))
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Editor for the Talk screen's welcome picture: a row of curated preset
/// icons plus the same "Choose photo"/"Take photo" trigger buttons as
/// the You/Child fields — picking a preset here clears any custom photo
/// (applyPhoto in ProfileView does the reverse when a new photo is
/// picked). HomeScreenPictureView (shared with TalkView) renders
/// whichever is currently set. No photo picking of its own — see
/// PhotoTarget's doc comment on ProfileView.
private struct HomeScreenPictureField: View {
    @AppStorage("homeScreenPhotoPath") private var photoPath = ""
    @AppStorage("homeScreenPreset") private var presetRaw = ""

    let onChoosePhoto: () -> Void
    let onTakePhoto: (() -> Void)?

    init(onChoosePhoto: @escaping () -> Void, onTakePhoto: @escaping () -> Void) {
        self.onChoosePhoto = onChoosePhoto
        // See matching comment on PhotoPickerField's init.
        self.onTakePhoto = UIImagePickerController.isSourceTypeAvailable(.camera) ? onTakePhoto : nil
    }

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

            HStack(spacing: 24) {
                Button(action: onChoosePhoto) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)

                if let onTakePhoto {
                    Button(action: onTakePhoto) {
                        Label("Take photo", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .controlSize(.small)
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
    }

    private func selectPreset(_ preset: HomeScreenPreset) {
        if !photoPath.isEmpty {
            try? FileManager.default.removeItem(atPath: photoPath)
            photoPath = ""
        }
        presetRaw = preset.rawValue
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
