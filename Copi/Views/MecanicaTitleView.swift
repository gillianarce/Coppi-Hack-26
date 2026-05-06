//
//  MecanicaTitleView.swift
//  Copi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI
import Speech
import AVFoundation
import Observation
import Lottie

// MARK: - Word-by-Word Speech Recognizer

/// Encapsula AVAudioEngine + SFSpeechRecognizer para la mecánica de letras.
/// Emite cada nueva palabra reconocida a través de `onWord`.
@MainActor
@Observable
final class WordSpeechRecognizer {

    // Callback que MecanicaTitleView suscribe
    var onWord: ((String) -> Void)?

    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private let audioEngine  = AVAudioEngine()
    private var request      : SFSpeechAudioBufferRecognitionRequest?
    private var task         : SFSpeechRecognitionTask?
    private var lastSent     : String = ""

    // MARK: Permissions

    func requestPermissions() async {
        await AVAudioApplication.requestRecordPermission()
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { _ in
                continuation.resume()
            }
        }
    }

    // MARK: Start / Stop

    func start() {
        guard !audioEngine.isRunning else { return }
        lastSent = ""

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        request = req

        let input = audioEngine.inputNode
        let fmt   = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.request?.append(buf)
        }

        task = recognizer?.recognitionTask(with: req) { [weak self] result, _ in
            guard let self, let result else { return }
            // Toma la última palabra de la transcripción parcial
            let words = result.bestTranscription.formattedString
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            guard let last = words.last, last != self.lastSent else { return }
            self.lastSent = last
            self.onWord?(last)
        }

        try? audioEngine.start()
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task    = nil
        lastSent = ""
    }
}

// MARK: - Burst Particle

private struct BurstParticle: Identifiable {
    let id   = UUID()
    let position: CGPoint
}

// MARK: - MecanicaTitleView

struct MecanicaTitleView: View {

    @EnvironmentObject private var coordinator: ActivitySessionCoordinator

    // ── Colores ──────────────────────────────────────────────────────────
    private let background  = Color(red: 1.00, green: 0.98, blue: 0.94)
    private let textoOscuro = Color(red: 0.18, green: 0.24, blue: 0.32)
    private let dorado      = Color(red: 0.93, green: 0.78, blue: 0.42)

    // ── Juego ────────────────────────────────────────────────────────────
    /// Letras del abecedario en orden (se omiten las raramente usadas en español)
    private let letras: [String] = (65...90)
        .map { String(UnicodeScalar($0)!) }
        .filter { $0 != "Q" && $0 != "X" && $0 != "W" }

    @State private var letterIndex   : Int = 0
    @State private var currentLetter : String = "A"
    @State private var category      : GameCategory = GameCategory.all[0]
    /// Palabras ya contadas en la letra actual para no repetir
    @State private var counted       : Set<String> = []

    // ── Timer ────────────────────────────────────────────────────────────
    /// Duración máxima de la actividad en segundos
    private let maxDuration: TimeInterval = 10
    @State private var timerTask: Task<Void, Never>? = nil

    // ── Speech ───────────────────────────────────────────────────────────
    @State private var speech      = WordSpeechRecognizer()
    @State private var isListening = false

    // ── Destellos ────────────────────────────────────────────────────────
    @State private var bursts: [BurstParticle] = []

    // ── Animación de letra ───────────────────────────────────────────────
    @State private var letterScale  : CGFloat = 1.0
    @State private var letterPulse  : CGFloat = 1.0   // pulso continuo bajo la letra

    // ── Geometría ────────────────────────────────────────────────────────
    @State private var containerSize: CGSize = .zero

    var body: some View {
        ZStack {

            // ── Lottie (capa 1 - fondo total) ────────────────────────────
            LottieView(animation: .named("1.1"))
                .playing(loopMode: .loop)
                .resizable()
                .frame(width: 600)
                .opacity(isListening ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isListening)

            // ── Destellos (fondo) ────────────────────────────────────────
            ForEach(bursts) { burst in
                BurstView(color: dorado)
                    .position(burst.position)
            }

            VStack(spacing: 0) {

                Spacer()

                // ── Instrucción ──────────────────────────────────────────
                MecanicaTitle(
                    prefix: "Nombra \(article(for: category)) ",
                    category: category,
                    suffix: "que comience con la letra…"
                )
                .padding(.horizontal, 32)
                Spacer()

                // ── Letra ────────────────────────────────────────────────
                Text(currentLetter)
                    .font(.custom("Poppins-Bold", size: 110))
                    .foregroundStyle(textoOscuro)
                    .scaleEffect(letterScale)
                    .padding(.top, 8)

                // ── Pulso dorado debajo de la letra ──────────────────────
                Circle()
                    .fill(dorado.opacity(0.35))
                    .frame(width: 18, height: 18)
                    .scaleEffect(letterPulse)
                    .opacity(2.0 - Double(letterPulse))   // desvanece al expandirse
                    .padding(.top, 6)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                        ) {
                            letterPulse = 1.6
                        }
                    }

                Spacer()

                // ── Indicador de escucha ─────────────────────────────────
                MicIndicator(isListening: isListening, dorado: dorado, texto: textoOscuro)
                    .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await speech.requestPermissions()
            setupRound()
            startListening()
            startTimer()
        }
        .onDisappear {
            timerTask?.cancel()
            speech.stop()
        }
    }

    // MARK: - Lógica de ronda

    /// Prepara la primera letra y elige categoría al inicio
    private func setupRound() {
        letterIndex   = 1
        category      = GameCategory.all.randomElement() ?? GameCategory.all[0]
        showLetter(letras[letterIndex])
    }

    /// Muestra la letra en posición `index` con animación de entrada
    private func showLetter(_ letter: String) {
        counted       = []
        currentLetter = letter
        letterScale   = 0.5
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            letterScale = 1.0
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task {
            try? await Task.sleep(for: .seconds(maxDuration))
            guard !Task.isCancelled else { return }
            finishActivity()
        }
    }

    private func finishActivity() {
        speech.stop()
        isListening = false
        timerTask?.cancel()
        coordinator.advance()
    }

    // MARK: - Speech

    private func startListening() {
        isListening = true
        speech.onWord = { [self] word in
            Task { @MainActor in
                evaluate(word: word)
            }
        }
        speech.start()
    }

    private func evaluate(word: String) {
        let clean = word
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .trimmingCharacters(in: .punctuationCharacters)

        guard clean.hasPrefix(currentLetter),
              !counted.contains(clean) else { return }

        counted.insert(clean)

        // Destello
        let cx = containerSize.width  / 2
        let cy = containerSize.height / 2
        let dx = CGFloat.random(in: -80...80)
        let dy = CGFloat.random(in: -80...80)
        spawnBurst(at: CGPoint(x: cx + dx, y: cy + dy))

        // Avanzar a la siguiente letra
        let nextIndex = letterIndex + 1
        if nextIndex < letras.count {
            letterIndex = nextIndex
            showLetter(letras[letterIndex])
        } else {
            // Recorrió todas las letras antes del tiempo → terminar
            finishActivity()
        }
    }

    // MARK: - Destellos

    private func spawnBurst(at point: CGPoint) {
        let particle = BurstParticle(position: point)
        bursts.append(particle)
        // Limpia después de que termina la animación
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            bursts.removeAll { $0.id == particle.id }
        }
    }

    // MARK: - Helpers

    private func article(for cat: GameCategory) -> String {
        // Artículo gramaticalmente correcto según la categoría
        let masc = ["Animal", "País", "Color", "Deporte", "Objeto", "Nombre"]
        return masc.contains(cat.name) ? "un" : "una"
    }
}

// MARK: - BurstView

/// Círculo degradado que aparece y se expande como destello.
private struct BurstView: View {
    let color: Color
    @State private var scale  : CGFloat = 0.1
    @State private var opacity: Double  = 0.85

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.9), color.opacity(0.5), color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 120
                )
            )
            .frame(width: 240, height: 240)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) {
                    scale   = 1.0
                    opacity = 0
                }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - MicIndicator

private struct MicIndicator: View {
    let isListening: Bool
    let dorado     : Color
    let texto      : Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isListening ? dorado.opacity(0.18) : Color.gray.opacity(0.1))
                    .frame(width: 72, height: 72)

                if isListening {
                    Circle()
                        .stroke(dorado.opacity(0.35), lineWidth: 2)
                        .frame(width: 88, height: 88)
                        .scaleEffect(isListening ? 1.0 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                            value: isListening
                        )
                }

                Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isListening ? dorado : Color.gray)
            }

            Text(isListening ? "Estoy escuchando…" : "Sin micrófono")
                .font(.custom("Poppins-Regular", size: 13))
                .foregroundStyle(texto.opacity(0.55))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MecanicaTitleView()
    }
    .environmentObject(ActivitySessionCoordinator())
}
