//
//  Respiracion478View.swift
//  Copi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI
import Lottie

// MARK: - Step Modela

private struct BreathStep {
    let instruction: String
    let duration: Int
}

private let breathSteps: [BreathStep] = [
    BreathStep(instruction: "Inhala",              duration: 4),
    BreathStep(instruction: "Conten la respiración", duration: 7),
    BreathStep(instruction: "Exhala despacio",     duration: 8),
]

// MARK: - Main View

struct Respiracion478View: View {

    /// Número de repetición actual (1-based)
    let totalRepetitions: Int = 4
    @State private var currentRepetition: Int = 1

    /// Índice del paso actual (0, 1, 2)
    @State private var stepIndex: Int = 0

    /// Contador del timer
    @State private var timeRemaining: Int = breathSteps[0].duration

    /// Tarea del timer activa
    @State private var timerTask: Task<Void, Never>? = nil

    /// Incrementa cada vez que se completa una vuelta completa (3 pasos).
    /// Usar como `id` en LottieView fuerza recreación solo en ese momento.
    @State private var lottieEpoch: Int = 0

    private var currentStep: BreathStep { breathSteps[stepIndex] }

    // Colores del diseño
    private let darkColor = Color(red: 0.25, green: 0.28, blue: 0.35)
    private let lightDotColor = Color(red: 0.80, green: 0.82, blue: 0.86)

    var body: some View {
        VStack(spacing: 0) {

            // ── Top section ───────────────────────────────────────────────
            VStack(spacing: 16) {

                // Repetición actual
                Text("\(currentRepetition)/\(totalRepetitions)")
                    .font(.custom("Poppins-Medium", size: 18))
                    .foregroundStyle(darkColor)

                // Indicador de pasos (círculos)
                StepDotsView(
                    total: breathSteps.count,
                    current: stepIndex,
                    activeColor: darkColor,
                    inactiveColor: lightDotColor
                )

                // Instrucción del paso
                Text(currentStep.instruction)
                    .font(.custom("Poppins-Bold", size: 28))
                    .foregroundStyle(darkColor)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: stepIndex)

                // Timer
                Text("\(timeRemaining)")
                    .font(.custom("Poppins-Bold", size: 110))
                    .foregroundStyle(darkColor)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeInOut(duration: 0.4), value: timeRemaining)
            }
            .padding(.top, 50)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)

            Spacer()

            // ── Bottom section — Animación Lottie ─────────────────────────
            LottieView(animation: .named("3.2"))
                .playing(loopMode: .autoReverse)
                .resizable()
                .frame(width: 600)
                .id(lottieEpoch) // solo se recrea cuando cambia lottieEpoch (vuelta 3→1)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - Timer Logic

    private func startTimer() {
        timerTask?.cancel()
        timeRemaining = currentStep.duration

        timerTask = Task {
            repeat {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                withAnimation {
                    timeRemaining -= 1
                }
            } while timeRemaining > 0

            guard !Task.isCancelled else { return }

            // Si acabamos de terminar el paso 3 (índice 2), recreamos Lottie
            // en este momento exacto — cuando el timer llega a 0 en el último paso
            if stepIndex == breathSteps.count - 1 {
                await MainActor.run { lottieEpoch += 1 }
            }

            await MainActor.run { advance() }
        }
    }

    private func advance() {
        let nextStep = stepIndex + 1
        if nextStep < breathSteps.count {
            // Paso 1→2 o 2→3: la animación Lottie sigue sin interrupciones
            stepIndex = nextStep
        } else {
            // Paso 3→1: nueva vuelta
            // lottieEpoch ya fue incrementado en startTimer cuando el paso 3 terminó
            stepIndex = 0
            if currentRepetition < totalRepetitions {
                currentRepetition += 1
            } else {
                currentRepetition = 1
            }
        }
        startTimer()
    }
}

// MARK: - Step Dots

private struct StepDotsView: View {
    let total: Int
    let current: Int
    let activeColor: Color
    let inactiveColor: Color

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? activeColor : inactiveColor)
                    .frame(width: 14, height: 14)
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Respiracion478View()
}
