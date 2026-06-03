import SwiftUI

struct QuotaAccountSkeletonRow: View {
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 6, height: 6)
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: index.isMultiple(of: 2) ? 138 : 188, height: 9)
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 30, height: 16)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.04))

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 96, height: 8)
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 300, height: 4)
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 58, height: 8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        )
    }
}
