import AppKit
import Foundation
import SwiftUI

@MainActor
final class ProviderImageLoader: ObservableObject {
    static let shared = ProviderImageLoader()

    private var cache: [URL: NSImage] = [:]
    private var inflightURLs: Set<URL> = []

    func image(for url: URL, basicAuth: BasicAuthCredentials?) async -> NSImage? {
        if let cached = cache[url] { return cached }
        if inflightURLs.contains(url) {
            while inflightURLs.contains(url) {
                try? await Task.sleep(nanoseconds: 50_000_000)
                if let cached = cache[url] { return cached }
            }
            return cache[url]
        }
        inflightURLs.insert(url)
        defer { inflightURLs.remove(url) }
        if let image = await fetch(url: url, basicAuth: basicAuth) {
            cache[url] = image
            return image
        }
        return nil
    }

    private func fetch(url: URL, basicAuth: BasicAuthCredentials?) async -> NSImage? {
        if let data = await loadData(url: url, basicAuth: basicAuth),
           let image = NSImage(data: data) {
            return image
        }
        if basicAuth != nil, let data = await loadData(url: url, basicAuth: nil),
           let image = NSImage(data: data) {
            return image
        }
        return nil
    }

    private func loadData(url: URL, basicAuth: BasicAuthCredentials?) async -> Data? {
        var request = URLRequest(url: url)
        if let basicAuth,
           Self.isLocalOrSecure(url),
           let header = basicAuth.authorizationHeader {
            request.setValue(header, forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private static func isLocalOrSecure(_ url: URL) -> Bool {
        if url.scheme == "https" { return true }
        guard url.scheme == "http" else { return false }
        let host = url.host ?? ""
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
}
