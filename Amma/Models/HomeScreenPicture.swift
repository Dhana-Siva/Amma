import SwiftUI

/// A small curated set of built-in "no upload needed" pictures for the
/// Talk screen's welcome image, offered alongside letting the parent
/// upload their own. Exactly one of a preset or a custom photo is active
/// at a time — choosing one clears the other, tracked via two separate
/// @AppStorage keys read by HomeScreenPictureView.
enum HomeScreenPreset: String, CaseIterable, Identifiable {
    case heart, sun, family, star, house, flower

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .heart: "heart.fill"
        case .sun: "sun.max.fill"
        case .family: "figure.2.and.child.holdinghands"
        case .star: "star.fill"
        case .house: "house.fill"
        case .flower: "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .heart: .pink
        case .sun: .orange
        case .family: .blue
        case .star: .yellow
        case .house: .green
        case .flower: .mint
        }
    }
}

/// Renders the parent's chosen "home screen" picture: a custom uploaded
/// photo if one is set, otherwise a chosen preset, otherwise a plain
/// generic placeholder. Used both in the Edit Profile preview and on the
/// Talk screen's welcome state, so both always stay in sync automatically
/// — this view owns no state of its own beyond reading the same
/// @AppStorage keys the editor (in ProfileView) writes to.
struct HomeScreenPictureView: View {
    @AppStorage("homeScreenPhotoPath") private var photoPath = ""
    @AppStorage("homeScreenPreset") private var presetRaw = ""

    var size: CGFloat = 132

    var body: some View {
        Group {
            if !photoPath.isEmpty, let image = UIImage(contentsOfFile: photoPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let preset = HomeScreenPreset(rawValue: presetRaw) {
                ZStack {
                    Circle().fill(preset.tint.opacity(0.15))
                    Image(systemName: preset.systemImage)
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(preset.tint)
                }
            } else {
                ZStack {
                    Circle().fill(Color(.systemGray5))
                    Image(systemName: "face.smiling")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
