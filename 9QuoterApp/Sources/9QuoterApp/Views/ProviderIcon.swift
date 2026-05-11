import SwiftUI

struct ProviderIcon: View {
    let provider: ProviderQuota
    let baseURL: String
    let size: CGFloat

    var body: some View {
        if let path = provider.providerIconURL,
           let url = URL(string: "\(baseURL)\(path)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
                case .failure, .empty:
                    fallbackIcon
                @unknown default:
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: provider.providerFallbackIcon)
            .font(.system(size: size * 0.7))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
    }
}
