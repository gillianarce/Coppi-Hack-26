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

    @EnvironmentObject private var coordinator: ActivitySessionCoordinator

    /// Número de repetición actual (1-based)
    let totalRepetitions: Int = 4
    @State private var currentRepetition: Int = 1

    /// Índice del paso actual (0, 1, 2)
    @State private var stepIndex: Int = 0

    /// Contador del timer
    @State private var timeRemaining: Int = breathSteps[0].duration

    /// Tarea del timer activa
    @State private var timerTask: Task<Void, Never>? = nil

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
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - Timer Logic

    private func startTimer() {
        timerTask?.cancel()
        let duration = currentStep.duration
        timeRemaining = duration

        timerTask = Task {
            // Use a fixed start time to avoid drift accumulation
            let start = Date.now
            for tick in 1...duration {
                // Sleep until the exact moment this tick should fire
                let target = start.addingTimeInterval(TimeInterval(tick))
                let delay = target.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation { timeRemaining = duration - tick }
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run { advance() }
        }
    }

    private func advance() {
        let nextStep = stepIndex + 1
        if nextStep < breathSteps.count {
            stepIndex = nextStep
        } else {
            stepIndex = 0
            if currentRepetition < totalRepetitions {
                currentRepetition += 1
            } else {
                // Última ronda completada → avanzar al siguiente paso de la sesión
                timerTask?.cancel()
                coordinator.advance()
                return
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
