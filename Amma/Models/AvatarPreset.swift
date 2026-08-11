import SwiftUI

/// Curated "character" avatars offered as an alternative to a real photo
/// for the small identity shown next to the child's name (Talk screen
/// toolbar) — for a parent who hasn't uploaded (or doesn't want to
/// upload) an actual photo of their son/daughter, or just wants a
/// friendlier look. Deliberately distinct iconography from
/// HomeScreenPreset (heart/sun/family/star/house/leaf) so the two
/// picture systems never look interchangeable.
enum AvatarPreset: String, CaseIterable, Identifiable {
    case smile, sparkle, wave, music

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smile: "Smiley"
        case .sparkle: "Sparkle"
        case .wave: "Wave"
        case .music: "Music"
        }
    }

    var systemImage: String {
        switch self {
        case .smile: "face.smiling.fill"
        case .sparkle: "sparkles"
        case .wave: "hand.wave.fill"
        case .music: "music.note"
        }
    }

    var tint: Color {
        switch self {
        case .smile: .orange
        case .sparkle: .purple
        case .wave: .teal
        case .music: .pink
        }
    }
}

/// Renders whichever avatar the parent has chosen: the child's own
/// uploaded photo (the default, and the "Son"/"Child" option in the
/// picker) if one is set and selected, otherwise a chosen character
/// preset, otherwise a plain placeholder. Shared between the Edit
/// Profile picker preview and the Talk screen toolbar so both always
/// agree — reads the same @AppStorage keys the editor writes to.
struct AvatarView: View {
    @AppStorage("childPhotoPath") private var childPhotoPath = ""
    @AppStorage("avatarUsesChildPhoto") private var usesChildPhoto = true
    @AppStorage("avatarPreset") private var presetRaw = ""

    var size: CGFloat = 32

    var body: some View {
        Group {
            if usesChildPhoto, !childPhotoPath.isEmpty, let image = UIImage(contentsOfFile: childPhotoPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let preset = AvatarPreset(rawValue: presetRaw) {
                ZStack {
                    Circle().fill(preset.tint.opacity(0.18))
                    Image(systemName: preset.systemImage)
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(preset.tint)
                }
            } else {
                ZStack {
                    Circle().fill(Color(.systemGray5))
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
