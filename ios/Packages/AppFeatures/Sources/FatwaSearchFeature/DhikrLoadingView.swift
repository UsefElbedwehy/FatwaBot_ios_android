import DesignSystemKit
import SwiftUI

/// Loading state for an in-flight `/v1/search` answer: the brand mark with a
/// rotating dhikr line underneath, covering LLM latency with something worth
/// reading rather than a bare spinner (per the client's reference app).
///
/// The four phrases are fixed Arabic dhikr text, not localized strings — like
/// the Tasbeeh presets (TasbeehModels.DhikrPreset), religious wording stays
/// Arabic regardless of the device locale.
struct DhikrLoadingView: View {
    let tokens: ColorTokens

    private static let phrases = ["سبحان الله", "الحمد لله", "الله أكبر", "لا إله إلا الله"]

    @State private var index = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            FatwaMark(color: Color(hexToken: tokens.primary))
                .frame(width: 64, height: 90)
                .opacity(pulse ? 1 : 0.55)
                .scaleEffect(pulse ? 1.0 : 0.94)
                .accessibilityHidden(true)

            Text(Self.phrases[index])
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.primary))
                .contentTransition(.opacity)
                .id(index)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .task {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.35)) {
                    index = (index + 1) % Self.phrases.count
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("fatwa_search.loading"))
    }
}
