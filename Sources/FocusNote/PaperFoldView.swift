import SwiftUI

/// Only shown during rollover: two clipped halves hinge toward one another.
/// The real editable page is never duplicated while the person is working.
struct PaperFoldView<Content: View>: View {
    let progress: Double
    let variant: Int
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            if variant == 2 {
                VStack(spacing: 0) {
                    half(size: geometry.size, alignment: .top)
                        .frame(height: geometry.size.height / 2)
                        .rotation3DEffect(.degrees(-85 * progress), axis: (x: 1, y: 0, z: 0), anchor: .bottom)
                    half(size: geometry.size, alignment: .bottom)
                        .frame(height: geometry.size.height / 2)
                        .rotation3DEffect(.degrees(85 * progress), axis: (x: 1, y: 0, z: 0), anchor: .top)
                }
            } else {
                HStack(spacing: 0) {
                    half(size: geometry.size, alignment: .leading)
                        .frame(width: geometry.size.width / 2)
                        .rotation3DEffect(.degrees((variant == 0 ? 85 : -85) * progress),
                                          axis: (x: 0, y: 1, z: 0), anchor: .trailing)
                    half(size: geometry.size, alignment: .trailing)
                        .frame(width: geometry.size.width / 2)
                        .rotation3DEffect(.degrees((variant == 0 ? -85 : 85) * progress),
                                          axis: (x: 0, y: 1, z: 0), anchor: .leading)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func half(size: CGSize, alignment: Alignment) -> some View {
        content
            .frame(width: size.width, height: size.height)
            .frame(width: variant == 2 ? size.width : size.width / 2,
                   height: variant == 2 ? size.height / 2 : size.height,
                   alignment: alignment)
            .clipped()
            .shadow(color: Color.primary.opacity(0.12), radius: Space.sm)
    }
}
