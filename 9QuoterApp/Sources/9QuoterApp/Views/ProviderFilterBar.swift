import SwiftUI

struct ProviderFilterBar: View {
    let options: [ProviderFilterOption]
    let selected: String?
    let baseURL: String
    let basicAuth: BasicAuthCredentials?
    let onSelect: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options) { option in
                    ProviderFilterChip(
                        option: option,
                        isActive: isActive(option),
                        baseURL: baseURL,
                        basicAuth: basicAuth
                    ) {
                        onSelect(chipSelection(option))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 1)
        }
        .padding(.bottom, 6)
    }

    private func isActive(_ option: ProviderFilterOption) -> Bool {
        switch option.id {
        case .all:
            return selected == nil
        case .provider(let key):
            return selected == key
        }
    }

    private func chipSelection(_ option: ProviderFilterOption) -> String? {
        switch option.id {
        case .all:
            return nil
        case .provider(let key):
            return key
        }
    }
}

private struct ProviderFilterChip: View {
    let option: ProviderFilterOption
    let isActive: Bool
    let baseURL: String
    let basicAuth: BasicAuthCredentials?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                chipIcon
                Text(option.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isActive ? .white.opacity(0.92) : .white.opacity(0.52))
                Text("\(option.count)")
                    .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isActive ? .white.opacity(0.62) : .white.opacity(0.3))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                isActive ? Color.purple.opacity(0.36) : Color.white.opacity(0.05),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? Color.purple.opacity(0.5) : Color.white.opacity(0.055),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chipIcon: some View {
        if let representative = option.representative {
            ProviderIcon(provider: representative, baseURL: baseURL, size: 14, basicAuth: basicAuth)
        } else {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isActive ? .white.opacity(0.72) : .white.opacity(0.38))
                .frame(width: 14, height: 14)
        }
    }
}
