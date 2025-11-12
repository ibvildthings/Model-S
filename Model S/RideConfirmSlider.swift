//
//  RideConfirmSlider.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

struct RideConfirmSlider: View {
    var configuration: RideRequestConfiguration = .default
    var onConfirmRide: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isConfirmed = false
    @State private var isRequesting = false

    private let sliderHeight: CGFloat = 64
    private let thumbSize: CGFloat = 56

    var body: some View {
        GeometryReader { geometry in
            let maxOffset = geometry.size.width - thumbSize - 8

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isRequesting
                                ? [.gray.opacity(0.3), .gray.opacity(0.3)]
                                : [Color(red: 0.1, green: 0.4, blue: 0.9), Color(red: 0.2, green: 0.7, blue: 0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: sliderHeight)

                // Progress indicator (fills as you slide)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.3, green: 0.8, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: offset + thumbSize / 2, height: sliderHeight)
                    .opacity(isRequesting ? 0 : (offset / maxOffset) * 0.5)

                // Text Label
                HStack {
                    Spacer()
                    Text(isRequesting ? configuration.requestingText : configuration.sliderText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .offset(x: isRequesting ? 0 : -thumbSize / 2)
                    Spacer()
                }
                .allowsHitTesting(false)

                // Draggable Thumb
                if !isRequesting {
                    Circle()
                        .fill(.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .overlay(
                            Image(systemName: "arrow.right")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(configuration.accentColor)
                        )
                        .offset(x: 4 + offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = max(0, min(value.translation.width, maxOffset))
                                    offset = newOffset

                                    // Haptic feedback at checkpoints
                                    if newOffset >= maxOffset * 0.5 && offset < maxOffset * 0.5 {
                                        hapticFeedback(style: .light)
                                    }
                                }
                                .onEnded { value in
                                    if offset >= maxOffset * 0.85 {
                                        // Confirmed! Complete the slide
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            offset = maxOffset
                                        }
                                        completeSlide()
                                    } else {
                                        // Snap back
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            offset = 0
                                        }
                                    }
                                }
                        )
                }

                // Loading indicator when requesting
                if isRequesting {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Spacer()
                    }
                }
            }
        }
        .frame(height: sliderHeight)
        .accessibilityLabel(isRequesting ? "Requesting ride" : "Slide to request ride")
        .accessibilityHint("Drag the slider to the right to confirm your ride request")
    }

    private func completeSlide() {
        isConfirmed = true
        successHapticFeedback()

        // Trigger the callback after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                isRequesting = true
            }
            onConfirmRide()
        }
    }

    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func successHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            RideConfirmSlider(onConfirmRide: {
                print("Ride confirmed!")
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}
