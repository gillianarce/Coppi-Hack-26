//
//  SplashView.swift
//  Coppi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI

// MARK: - Arched Text

/// Renders `text` curved along the top arc of a circle with the given `radius`.
/// `letterSpacing` controls the angular gap between characters.
struct ArcText: View {
    let text: String
    let radius: CGFloat
    let letterSpacing: CGFloat

    init(_ text: String, radius: CGFloat, letterSpacing: CGFloat = 1.0) {
        self.text = text
        self.radius = radius
        self.letterSpacing = letterSpacing
    }

    var body: some View {
        // Each character is placed at an angle relative to the top of the circle
        let characters = Array(text)
        // Base the angular step on the actual font size so letters never overlap.
        // fontSize / radius gives the arc length in radians; letterSpacing scales it.
        let fontSize: CGFloat = 30
        let anglePerChar = Double(fontSize * letterSpacing / radius)
        let totalAngle = anglePerChar * Double(characters.count - 1)
        let startAngle = -totalAngle / 2

        ZStack {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, char in
                let angle = startAngle + anglePerChar * Double(index)
                // -π/2 puts us at the top; we offset from there
                let radians = angle - (.pi / 2)

                Text(String(char))
                    .font(.custom("Poppins-Bold", size: 36))
                    .foregroundStyle(.white)
                    .rotationEffect(.radians(angle))
                    .offset(
                        x: radius * cos(radians),
                        y: radius * sin(radians)
                    )
            }
        }
    }
}

// MARK: - Splash View

struct SplashView: View {
    @State private var isInflated = false
    @State private var label = "Inhala"
    @State private var textArcRadius: CGFloat = 200
    @State private var textVisible = true

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let screenHeight = geo.size.height
            let circleDiameter = screenWidth * 1.05
            let circleRadius = circleDiameter / 2

            let scale: CGFloat = isInflated ? 1.3 : 1.0
            let circleCenterY = screenHeight - circleRadius + circleDiameter * 0.45
            let circleTopY = circleCenterY - circleRadius * scale
            let textCenterY = circleTopY - textArcRadius - 2

            ZStack(alignment: .bottom) {
                // Background
                Color(red: 0.36, green: 0.54, blue: 0.64)
                    .ignoresSafeArea()

                // Circle anchored to the bottom, scales up from there
                Circle()
                    .fill(Color(red: 0.99, green: 0.85, blue: 0.51))
                    .frame(width: circleDiameter, height: circleDiameter)
                    .offset(y: circleDiameter * 0.45)
                    .scaleEffect(isInflated ? 1.3 : 1.0, anchor: .bottom)
                    .animation(.snappy(duration: 3), value: isInflated)

                // Arched label — se oculta detrás del círculo para cambiar el texto sin que se note
                ArcText(label, radius: textArcRadius)
                    .position(x: screenWidth / 2, y: textCenterY)
                    .animation(.snappy(duration: 3), value: textArcRadius)
                    .opacity(textVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: textVisible)
            }
            .onAppear {
                startBreathingCycle()
            }
        }
    }

    // MARK: - Breathing cycle

    private func startBreathingCycle() {
        // El texto ya está visible con "Inhala", arrancamos a inflar
        withAnimation(.snappy(duration: 3)) {
            isInflated = true
            textArcRadius = 150
        }

        Task {
            // Esperar a que termine el ciclo de inhalar
            try? await Task.sleep(for: .seconds(3))

            // Ocultar el texto (se "mete" detrás del círculo)
            textVisible = false

            // Breve pausa para que el fade termine antes de cambiar la palabra
            try? await Task.sleep(for: .seconds(0.3))
            label = "Exhala"

            // Empezar a desinflar y hacer aparecer el texto de nuevo
            withAnimation(.snappy(duration: 3)) {
                isInflated = false
                textArcRadius = 200
            }
            textVisible = true

            // Esperar a que termine el ciclo de exhalar
            try? await Task.sleep(for: .seconds(3))

            // Volver a ocultar para cambiar a "Inhala"
            textVisible = false
            try? await Task.sleep(for: .seconds(0.3))
            label = "Inhala"
            textVisible = true

            startBreathingCycle()
        }
    }
}

#Preview {
    SplashView()
}
