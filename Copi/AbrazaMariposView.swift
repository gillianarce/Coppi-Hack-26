//
//  AbrazaMariposView.swift
//  Copi
//
//  Created by Kxze on 06/05/26.
//

import SwiftUI
import Lottie
import Combine

// MARK: - Hug ViewModel

private final class HugViewModel: ObservableObject {
    @Published var holdSeconds: Int = 0
    @Published var exerciseComplete = false

    private let targetHoldSeconds = 6
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        holdSeconds = 0
        exerciseComplete = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.holdSeconds += 1
            if self.holdSeconds >= self.targetHoldSeconds {
                self.exerciseComplete = true
                self.timer?.invalidate()
                self.timer = nil
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { timer?.invalidate() }
}

// MARK: - AbrazaMariposView

struct AbrazaMariposView: View {
    @EnvironmentObject private var coordinator: ActivitySessionCoordinator
    @StateObject private var viewModel = HugViewModel()

    private let textoOscuro = Color(red: 0.18, green: 0.24, blue: 0.32)
    private let dorado      = Color(red: 0.93, green: 0.78, blue: 0.42)

    var body: some View {
        mainContent
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.exerciseComplete) { _, complete in
            if complete {
                coordinator.advance()
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {

            // ── Header ──────────────────────────────────────────────────
            VStack(spacing: 6) {
                Text("Cruza los brazos sobre el\npecho en posición de")
                    .font(.custom("Poppins-Regular", size: 22))
                    .foregroundStyle(textoOscuro)
                    .multilineTextAlignment(.center)

                Text("Abrazo")
                    .font(.custom("Poppins-Bold", size: 26))
                    .foregroundStyle(dorado)
            }
            .padding(.top, 64)
            .padding(.horizontal, 32)

            // ── Progress ring ────────────────────────────────────────────
            ZStack {
                Circle()
                    .stroke(dorado.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(dorado, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: holdProgress)

                Text("\(viewModel.holdSeconds)s")
                    .font(.custom("Poppins-Bold", size: 20))
                    .foregroundStyle(textoOscuro)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.holdSeconds)
            }
            .padding(.top, 24)

            Spacer()

            // ── Lottie character ────────────────────────────────────────
            LottieView(animation: .named("2.3"))
                .playing(loopMode: .autoReverse)
                .resizable()
                .frame(width: 600)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Completion

    private var completionContent: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(dorado)

            VStack(spacing: 8) {
                Text("¡Ejercicio completado!")
                    .font(.custom("Poppins-Bold", size: 28))
                    .foregroundStyle(textoOscuro)
                    .multilineTextAlignment(.center)

                Text("Mantuviste el abrazo durante\n\(viewModel.holdSeconds) segundos")
                    .font(.custom("Poppins-Regular", size: 17))
                    .foregroundStyle(textoOscuro.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button {
                coordinator.advance()
            } label: {
                Text("Continuar")
                    .font(.custom("Poppins-Bold", size: 18))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(dorado, in: Capsule())
                    .shadow(color: dorado.opacity(0.4), radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed

    private var holdProgress: CGFloat {
        min(CGFloat(viewModel.holdSeconds) / 6.0, 1.0)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AbrazaMariposView()
    }
}
