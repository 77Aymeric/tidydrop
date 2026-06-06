import SwiftUI

extension View {
    @ViewBuilder
    func tidydropGlass(cornerRadius: CGFloat = 24) -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
