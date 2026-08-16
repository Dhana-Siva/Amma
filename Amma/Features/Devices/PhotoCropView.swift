import SwiftUI

/// A "Move and Scale" style circular crop step shown right after picking
/// or taking a photo, for any of the three photo slots in Edit Profile —
/// lets the parent pinch/pan to actually center a face in the frame
/// instead of always getting whatever the library/camera photo's plain
/// center crop happened to land on.
///
/// The on-screen circular window is just a guide (dimmed mask + white
/// ring); the image itself is clipped to a square both on screen and in
/// the rendered output, since every place this app displays a saved
/// photo already re-applies its own `.clipShape(Circle())` — cropping to
/// a circle here too would just be redundant work on a JPEG that can't
/// hold the transparency anyway.
struct PhotoCropView: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 300

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    croppableImage
                        .frame(width: cropDiameter, height: cropDiameter)
                        .clipped()
                        .overlay(circleGuide)
                        .contentShape(Rectangle())
                        .gesture(dragGesture)
                        .gesture(magnificationGesture)

                    Text("Pinch to zoom, drag to reposition")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()
                }
            }
            .navigationTitle("Move and Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        onConfirm(renderCroppedImage())
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var croppableImage: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: cropDiameter, height: cropDiameter)
            .scaleEffect(scale)
            .offset(offset)
    }

    private var circleGuide: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .reverseMask { Circle() }
            Circle().stroke(.white, lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1, min(4, lastScale * value))
            }
            .onEnded { _ in lastScale = scale }
    }

    @MainActor
    private func renderCroppedImage() -> UIImage {
        let renderer = ImageRenderer(
            content: croppableImage
                .frame(width: cropDiameter, height: cropDiameter)
                .clipped()
        )
        renderer.scale = 3
        return renderer.uiImage ?? image
    }
}

private extension View {
    /// Fills with the current foreground content everywhere *except* the
    /// given shape — used to dim the area outside the circular crop guide
    /// without needing a second overlapping view.
    func reverseMask<Mask: Shape>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask().blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}
