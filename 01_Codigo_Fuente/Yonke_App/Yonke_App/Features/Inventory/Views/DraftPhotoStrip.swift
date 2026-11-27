import SwiftUI

// MARK: - DraftPhotoStrip
/// Horizontal strip of inventory photos for a draft.

struct DraftPhotoStrip: View {
    let photos: [String]

    var body: some View {
        if photos.isEmpty {
            Text("Sin fotos registradas en inventario")
                .font(.footnote)
                .foregroundStyle(YonkeTheme.textMuted)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(photos.compactMap { URL(string: $0) }, id: \.self) { url in
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(.rect(cornerRadius: 6))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
