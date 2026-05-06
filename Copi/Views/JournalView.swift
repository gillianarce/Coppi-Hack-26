//
//  JournalView.swift
//  Coppi
//
//  Created by Kxze on 06/05/26.
//

import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Speech Recognizer

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var permissionDenied: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Texto de segmentos anteriores ya confirmados (isFinal)
    private var confirmedText: String = ""
    /// true mientras el usuario pidió parar, para ignorar callbacks tardíos
    private var isStopping = false

    init() {
        // Forzar español; si no está disponible se cae a es-MX como respaldo
        let esES = Locale(identifier: "es-ES")
        let esMX = Locale(identifier: "es-MX")
        if SFSpeechRecognizer.supportedLocales().contains(esES) {
            recognizer = SFSpeechRecognizer(locale: esES)
        } else {
            recognizer = SFSpeechRecognizer(locale: esMX)
        }
        recognizer?.defaultTaskHint = .dictation
    }

    // MARK: - Toggle

    func toggleRecording() {
        isRecording ? stopRecording() : requestAndStart()
    }

    // MARK: - Permissions + Start

    private func requestAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                switch status {
                case .authorized:
                    self.confirmedText = ""
                    self.transcript    = ""
                    self.isStopping    = false
                    self.beginSession()
                default:
                    self.permissionDenied = true
                }
            }
        }
    }

    // MARK: - Begin a recognition session
    // El engine se crea fresco cada vez para evitar estados sucios entre sesiones.

    private func beginSession() {
        // 1. Audio Session
        let avSession = AVAudioSession.sharedInstance()
        do {
            try avSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try avSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        // 2. Request de reconocimiento
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Usar el modelo del dispositivo (más preciso que el de la nube)
        request.requiresOnDeviceRecognition = false
        // Hint de dictado: optimiza para frases largas y vocabulario general
        request.taskHint = .dictation
        // Añadir palabras del dominio para mejorar precisión emocional
        request.contextualStrings = [
            "ansioso", "ansiosidad", "angustia", "tristeza", "triste",
            "feliz", "felicidad", "alegría", "estrés", "estresado",
            "cansado", "agotado", "motivado", "preocupado", "preocupación",
            "nervioso", "tranquilo", "tranquilidad", "deprimido", "emocionado"
        ]
        recognitionRequest = request

        // 3. Instalar tap ANTES de arrancar el engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        // 4. Arrancar el engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cleanupEngine()
            return
        }

        // 5. Lanzar tarea de reconocimiento
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, !self.isStopping else { return }

                if let result {
                    let partial = result.bestTranscription.formattedString
                    self.transcript = self.confirmedText.isEmpty
                        ? partial
                        : self.confirmedText + " " + partial

                    if result.isFinal {
                        // Guardar el texto confirmado y reiniciar sesión sin parar el engine
                        self.confirmedText = self.transcript
                        self.restartSession()
                    }
                }

                if let error, !self.isStopping {
                    let code = (error as NSError).code
                    // 301/203 = silencio / timeout → reiniciar silenciosamente
                    if code == 301 || code == 203 {
                        self.restartSession()
                    } else {
                        self.tearDown()
                    }
                }
            }
        }

        isRecording = true
    }

    // MARK: - Restart session (isFinal o timeout, sin parar el engine)

    private func restartSession() {
        // Terminar sólo la tarea y el request, dejar el engine corriendo
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine.inputNode.removeTap(onBus: 0)

        guard !isStopping else { return }

        // Leve pausa antes de reinstalar el tap
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, !self.isStopping else { return }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            request.taskHint = .dictation
            request.contextualStrings = [
                "ansioso", "ansiosidad", "angustia", "tristeza", "triste",
                "feliz", "felicidad", "alegría", "estrés", "estresado",
                "cansado", "agotado", "motivado", "preocupado", "preocupación",
                "nervioso", "tranquilo", "tranquilidad", "deprimido", "emocionado"
            ]
            self.recognitionRequest = request

            let inputNode = self.audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }

            self.recognitionTask = self.recognizer?.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self, !self.isStopping else { return }

                    if let result {
                        let partial = result.bestTranscription.formattedString
                        self.transcript = self.confirmedText.isEmpty
                            ? partial
                            : self.confirmedText + " " + partial
                        if result.isFinal {
                            self.confirmedText = self.transcript
                            self.restartSession()
                        }
                    }
                    if let error, !self.isStopping {
                        let code = (error as NSError).code
                        if code == 301 || code == 203 {
                            self.restartSession()
                        } else {
                            self.tearDown()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stop (usuario)

    func stopRecording() {
        isStopping = true
        tearDown()
    }

    // MARK: - Teardown completo

    private func tearDown() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        cleanupEngine()
        isRecording = false
        // transcript se conserva intacto
    }

    private func cleanupEngine() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        // Crear un engine nuevo listo para la próxima sesión
        audioEngine = AVAudioEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Journal View

struct JournalView: View {
    @StateObject private var speech = SpeechRecognizer()
    @State private var pulseScale: CGFloat = 1.0
    @State private var isEditing: Bool = false
    @State private var editableText: String = ""
    @FocusState private var editorFocused: Bool

    // Amarillo del sistema de diseño
    private let accentYellow = Color(red: 0.99, green: 0.85, blue: 0.51)
    // Azul oscuro del sistema de diseño (textos del splash / mic icon)
    private let darkBlue = Color(red: 0.22, green: 0.32, blue: 0.40)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .bottom) {

                // ── Fondo blanco ──────────────────────────────────────
                Color(red: 0.99, green: 0.98, blue: 0.95)
                    .ignoresSafeArea()

                // ── Toca fuera del editor para cerrar teclado ─────────
                if isEditing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { commitEdit() }
                        .ignoresSafeArea()
                }

                // ── Gran círculo amarillo anclado abajo ───────────────
                Circle()
                    .fill(accentYellow)
                    .frame(width: w * 1.1, height: w * 1.1)
                    .offset(y: w * 0.36)
                    // Pulso sutil mientras graba
                    .scaleEffect(speech.isRecording ? pulseScale : 1.0, anchor: .bottom)
                    .animation(
                        speech.isRecording
                            ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                            : .easeInOut(duration: 0.4),
                        value: pulseScale
                    )

                // ── Contenido principal ───────────────────────────────
                VStack(spacing: 0) {

                    // — Título
                    Text("¿Cómo te sientes\nahora?")
                        .font(.custom("Poppins-Bold", size: 28))
                        .foregroundStyle(darkBlue)
                        .multilineTextAlignment(.center)
                        .padding(.top, h * 0.07)
                        .padding(.horizontal, 32)

                    // — Caja de transcripción
                    transcriptBox
                        .padding(.top, 28)
                        .padding(.horizontal, 24)

                    Spacer()

                    // — Botón de micrófono (oculto mientras se edita)
                    if !isEditing {
                        micButton
                            .padding(.bottom, h * 0.06)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.35), value: isEditing)
            }
            .onChange(of: speech.isRecording) { _, recording in
                pulseScale = recording ? 1.06 : 1.0
            }
            // Sincronizar el texto del speech con el editor cuando no se está editando
            .onChange(of: speech.transcript) { _, newValue in
                if !isEditing {
                    editableText = newValue
                }
            }
            .alert("Permiso denegado", isPresented: $speech.permissionDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Activa el micrófono y el reconocimiento de voz en Configuración para usar esta función.")
            }
        }
        .navigationBarBackButtonHidden(false)
    }

    // MARK: - Commit / cancel edición

    private func commitEdit() {
        // Propaga el texto editado de vuelta al speech recognizer
        speech.transcript = editableText
        isEditing = false
        editorFocused = false
    }

    // MARK: - Subviews

    private var transcriptBox: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

            if isEditing {
                // ── Modo edición ──────────────────────────────────────
                VStack(alignment: .trailing, spacing: 8) {
                    TextEditor(text: $editableText)
                        .font(.custom("Poppins-Regular", size: 17))
                        .foregroundStyle(darkBlue)
                        .scrollContentBackground(.hidden)
                        .focused($editorFocused)
                        .frame(minHeight: 140, maxHeight: 200)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Botón "Listo"
                    Button(action: commitEdit) {
                        Text("Listo")
                            .font(.custom("Poppins-Bold", size: 14))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(darkBlue, in: Capsule())
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
            } else {
                // ── Modo lectura — toda la caja es tappable ───────────
                Button {
                    guard !speech.isRecording else { return }
                    isEditing = true
                    editorFocused = true
                } label: {
                    ZStack(alignment: .topLeading) {
                        // Placeholder
                        if editableText.isEmpty {
                            Text(speech.isRecording ? "Escuchando…" : "Toca para escribir o editar")
                                .font(.custom("Poppins-Regular", size: 17))
                                .foregroundStyle(darkBlue.opacity(0.35))
                                .padding(20)
                        }

                        Text(editableText)
                            .font(.custom("Poppins-Regular", size: 17))
                            .foregroundStyle(darkBlue)
                            .multilineTextAlignment(.center)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 240)
                    // Indicador sutil de que es editable (solo cuando no graba)
                    .overlay(alignment: .bottomTrailing) {
                        if !speech.isRecording {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(darkBlue.opacity(0.25))
                                .padding(12)
                        }
                    }
                }
                .buttonStyle(.plain)
                // Feedback háptico sutil al entrar en edición
                .sensoryFeedback(.selection, trigger: isEditing)
            }
        }
        .frame(minHeight: 180, maxHeight: isEditing ? 280 : 240)
        .animation(.spring(duration: 0.3), value: isEditing)
    }

    private var micButton: some View {
        VStack(spacing: 14) {
            Button {
                speech.toggleRecording()
            } label: {
                ZStack {
                    // Anillo exterior (visible solo al grabar)
                    Circle()
                        .fill(Color.white.opacity(speech.isRecording ? 0.35 : 0))
                        .frame(width: 88, height: 88)

                    // Círculo blanco principal
                    Circle()
                        .fill(Color.white)
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)

                    // Ícono SF Symbol
                    Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(darkBlue)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(speech.isRecording ? 1.08 : 1.0)
            .animation(.spring(duration: 0.3), value: speech.isRecording)

            Text(speech.isRecording ? "Presiona para detener" : "Presiona para comenzar a grabar")
                .font(.custom("Poppins-Regular", size: 14))
                .foregroundStyle(darkBlue.opacity(0.7))
        }
    }
}

#Preview {
    JournalView()
}
