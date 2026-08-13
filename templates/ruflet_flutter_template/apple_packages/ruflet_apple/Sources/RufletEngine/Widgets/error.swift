import SwiftUI

public struct ErrorControl: View {
    public let message: String
    public let description: String?

    public init(_ message: String, description: String? = nil) {
        self.message = message
        self.description = description
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            if let description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .textSelection(.enabled)
        .padding(5)
        .background(Color.red, in: RoundedRectangle(cornerRadius: 3))
    }
}
