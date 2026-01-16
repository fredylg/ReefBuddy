import SwiftUI

/// A brutalist-styled loading view with animated elements
struct BrutalistLoadingView: View {
    @State private var animationPhase: Int = 0
    @State private var progressValue: CGFloat = 0
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    private let loadingTexts = [
        "ANALYZING...",
        "PROCESSING DATA...",
        "CALCULATING DOSING...",
        "GENERATING REPORT..."
    ]
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            // Main container
            VStack(spacing: BrutalistTheme.Spacing.lg) {
                // Animated title
                Text(loadingTexts[animationPhase % loadingTexts.count])
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(BrutalistTheme.Colors.background)
                    .animation(.easeInOut(duration: 0.2), value: animationPhase)
                
                // Progress bar container
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    // Progress bar
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(BrutalistTheme.Colors.text.opacity(0.2))
                            .frame(height: 16)
                        
                        // Progress fill
                        Rectangle()
                            .fill(BrutalistTheme.Colors.action)
                            .frame(width: progressValue, height: 16)
                            .animation(.easeInOut(duration: 0.4), value: progressValue)
                    }
                    .frame(width: 250, height: 16)
                    .brutalistBorder(width: 3, color: BrutalistTheme.Colors.background)
                    
                    // Status dots
                    HStack(spacing: BrutalistTheme.Spacing.md) {
                        ForEach(0..<4) { index in
                            Circle()
                                .fill(index <= animationPhase % 4 
                                      ? BrutalistTheme.Colors.action 
                                      : BrutalistTheme.Colors.text.opacity(0.2))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(BrutalistTheme.Colors.background, lineWidth: 2)
                                )
                                .animation(.easeInOut(duration: 0.2), value: animationPhase)
                        }
                    }
                }
                
                // AI indicator
                HStack(spacing: BrutalistTheme.Spacing.xs) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("AI GATEWAY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .foregroundColor(BrutalistTheme.Colors.action)
                .padding(.horizontal, BrutalistTheme.Spacing.sm)
                .padding(.vertical, BrutalistTheme.Spacing.xs)
                .background(BrutalistTheme.Colors.text)
                .brutalistBorder(width: 2, color: BrutalistTheme.Colors.action)
            }
            .padding(BrutalistTheme.Spacing.xl)
            .background(BrutalistTheme.Colors.text)
            .brutalistBorder(width: 4, color: BrutalistTheme.Colors.action)
            .brutalistShadow(color: BrutalistTheme.Colors.action.opacity(0.5), offset: 8)
        }
        .onReceive(timer) { _ in
            animationPhase += 1
            // Animate progress bar
            withAnimation {
                progressValue = CGFloat((animationPhase % 5) + 1) / 5.0 * 250
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BrutalistLoadingView()
}
