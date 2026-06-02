import SwiftUI

struct ProviderIcon: View {
    let provider: ProviderQuota
    let baseURL: String
    let size: CGFloat
    var basicAuth: BasicAuthCredentials? = nil

    @State private var image: NSImage?
    @StateObject private var loader = ProviderImageLoader.shared

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                fallbackIcon
            }
        }
        .task(id: iconURL()) {
            guard let url = iconURL() else { return }
            image = await loader.image(for: url, basicAuth: basicAuth)
        }
    }

    private func iconURL() -> URL? {
        if let apiPath = provider.providerIconURL,
           let resolved = resolveURL(for: apiPath) {
            return resolved
        }
        guard let base = URL(string: baseURL) else { return nil }
        let path = "providers/\(provider.provider).png"
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    private func resolveURL(for path: String) -> URL? {
        if let absolute = URL(string: path), absolute.scheme != nil {
            return absolute
        }
        guard let base = URL(string: baseURL) else { return nil }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    private var fallbackIcon: some View {
        Image(systemName: provider.providerFallbackIcon)
            .font(.system(size: size * 0.7))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
    }
}
