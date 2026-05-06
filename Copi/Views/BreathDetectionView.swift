//
//  BreathDetectionView.swift
//  Copi
//

import SwiftUI
import Combine
import AVFoundation
import Vision

// MARK: - Breathing Phase

enum BreathingPhase {
    case inhaling
    case exhaling
    case unknown
}

// MARK: - Camera Manager

final class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.copi.vision", qos: .userInitiated)

    var onBodyPoseDetected: ((_ neck: CGPoint, _ leftShoulder: CGPoint, _ rightShoulder: CGPoint) -> Void)?

    @Published var permissionGranted = false
    @Published var cameraUnavailable = false

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.permissionGranted = true }
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { self?.permissionGranted = granted }
                if granted { self?.setupCamera() }
            }
        default:
            DispatchQueue.main.async { self.permissionGranted = false }
        }
    }

    private func setupCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { self.cameraUnavailable = true }
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()

        processingQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopSession() {
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return }

            let neck = try observation.recognizedPoint(.neck)
            let leftShoulder = try observation.recognizedPoint(.leftShoulder)
            let rightShoulder = try observation.recognizedPoint(.rightShoulder)

            guard neck.confidence > 0.3,
                  leftShoulder.confidence > 0.3,
                  rightShoulder.confidence > 0.3 else { return }

            onBodyPoseDetected?(
                neck.location,
                leftShoulder.location,
                rightShoulder.location
            )
        } catch {
            // Skip this frame
        }
    }
}

// MARK: - Respiratory ViewModel

final class RespiratoryViewModel: ObservableObject {
    @Published var breathingPhase: BreathingPhase = .unknown
    @Published var breathingIntensity: CGFloat = 0.5
    @Published var breathsPerMinute: Double = 0
    @Published var isDetecting = false
    @Published var rhythmDescription: String = "Detectando..."

    private var positionBuffer: [CGFloat] = []
    private let bufferSize = 30
    private var peakTimes: [Date] = []
    private var lastPhase: BreathingPhase = .unknown
    private var minValue: CGFloat = .greatestFiniteMagnitude
    private var maxValue: CGFloat = -.greatestFiniteMagnitude

    // Called from the Vision processing queue — dispatches UI updates to main
    func processJoints(neck: CGPoint, leftShoulder: CGPoint, rightShoulder: CGPoint) {
        let shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2.0
        let verticalDistance = neck.y - shoulderMidY

        DispatchQueue.main.async { [weak self] in
            self?.updateBreathing(with: verticalDistance)
        }
    }

    private func updateBreathing(with verticalDistance: CGFloat) {
        positionBuffer.append(verticalDistance)
        if positionBuffer.count > bufferSize {
            positionBuffer.removeFirst()
        }

        guard positionBuffer.count >= 5 else { return }

        // Moving-average smoothing
        let windowSize = min(5, positionBuffer.count)
        let recentValues = Array(positionBuffer.suffix(windowSize))
        let smoothedValue = recentValues.reduce(0, +) / CGFloat(windowSize)

        // Adaptive min/max with slow decay toward center
        if smoothedValue < minValue { minValue = smoothedValue }
        if smoothedValue > maxValue { maxValue = smoothedValue }

        let center = (minValue + maxValue) / 2.0
        minValue += (center - minValue) * 0.002
        maxValue -= (maxValue - center) * 0.002

        let range = maxValue - minValue
        guard range > 0.0001 else {
            isDetecting = false
            return
        }

        // Normalize intensity to [0, 1]
        let normalized = (smoothedValue - minValue) / range
        breathingIntensity = min(max(normalized, 0), 1)

        // Phase detection: compare smoothed value against an older window
        let newPhase: BreathingPhase
        if positionBuffer.count >= 8 {
            let olderWindow = Array(positionBuffer.suffix(8).prefix(3))
            let olderSmoothed = olderWindow.reduce(0, +) / CGFloat(olderWindow.count)
            let threshold = range * 0.05

            if smoothedValue > olderSmoothed + threshold {
                newPhase = .exhaling
            } else if smoothedValue < olderSmoothed - threshold {
                newPhase = .inhaling
            } else {
                newPhase = lastPhase
            }
        } else {
            newPhase = lastPhase
        }

        // Track peak transitions (inhale → exhale) for BPM
        if lastPhase == .inhaling && newPhase == .exhaling {
            peakTimes.append(Date())
            if peakTimes.count > 10 {
                peakTimes.removeFirst()
            }
            calculateBPM()
        }

        lastPhase = newPhase
        breathingPhase = newPhase
        isDetecting = true
    }

    private func calculateBPM() {
        guard peakTimes.count >= 2 else { return }
        let intervals = zip(peakTimes.dropFirst(), peakTimes).map { $0.timeIntervalSince($1) }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard avgInterval > 0.5 else { return }
        breathsPerMinute = 60.0 / avgInterval
        rhythmDescription = classifyRhythm(bpm: breathsPerMinute)
    }

    private func classifyRhythm(bpm: Double) -> String {
        switch bpm {
        case ..<10:  return "Respiración profunda"
        case 10..<16: return "Ritmo relajado"
        case 16..<22: return "Ritmo normal"
        case 22..<30: return "Ritmo acelerado"
        default:      return "Ritmo muy rápido"
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Breath Detection View

struct BreathDetectionView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var viewModel = RespiratoryViewModel()

    private let darkColor   = Color(red: 0.25, green: 0.28, blue: 0.35)
    private let accentYellow = Color(red: 0.99, green: 0.85, blue: 0.51)

    var body: some View {
        ZStack {
            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.captureSession)
                    .ignoresSafeArea()

                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                breathingContent
            } else if cameraManager.cameraUnavailable {
                noCameraView
            } else {
                permissionView
            }
        }
        .onAppear {
            cameraManager.onBodyPoseDetected = { neck, leftShoulder, rightShoulder in
                viewModel.processJoints(
                    neck: neck,
                    leftShoulder: leftShoulder,
                    rightShoulder: rightShoulder
                )
            }
            cameraManager.checkPermission()
        }
        .onDisappear {
            cameraManager.onBodyPoseDetected = nil
            cameraManager.stopSession()
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Main Content

    private var breathingContent: some View {
        VStack(spacing: 0) {
            Text("Detección de Respiración")
                .font(.custom("Poppins-Bold", size: 24))
                .foregroundStyle(.white)
                .padding(.top, 60)

            Spacer()

            // Animated breathing circle
            ZStack {
                Circle()
                    .fill(accentYellow.opacity(0.15))
                    .frame(width: circleSize + 50, height: circleSize + 50)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentYellow, accentYellow.opacity(0.6)],
                            center: .center,
                            startRadius: 0,
                            endRadius: circleSize / 2
                        )
                    )
                    .frame(width: circleSize, height: circleSize)

                VStack(spacing: 8) {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(darkColor)

                    Text(phaseText)
                        .font(.custom("Poppins-Bold", size: 20))
                        .foregroundStyle(darkColor)
                }
            }
            .animation(.easeInOut(duration: 1.0), value: viewModel.breathingIntensity)

            Spacer()

            // Stats panel
            statsPanel
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
        }
    }

    private var statsPanel: some View {
        VStack(spacing: 16) {
            if viewModel.isDetecting {
                if viewModel.breathsPerMinute > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 20))
                            .foregroundStyle(accentYellow)
                        Text(String(format: "%.0f resp/min", viewModel.breathsPerMinute))
                            .font(.custom("Poppins-Medium", size: 18))
                            .foregroundStyle(.white)
                    }

                    Text(viewModel.rhythmDescription)
                        .font(.custom("Poppins-Bold", size: 22))
                        .foregroundStyle(accentYellow)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(accentYellow)
                        Text("Analizando ritmo...")
                            .font(.custom("Poppins-Medium", size: 18))
                            .foregroundStyle(.white)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.rectangle")
                        .font(.system(size: 36))
                        .foregroundStyle(accentYellow)
                    Text("Colócate frente a la cámara")
                        .font(.custom("Poppins-Bold", size: 18))
                        .foregroundStyle(.white)
                    Text("Asegúrate de que tus hombros\ny cuello sean visibles")
                        .font(.custom("Poppins-Medium", size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Fallback Views

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(accentYellow)
            Text("Se necesita acceso a la cámara")
                .font(.custom("Poppins-Bold", size: 20))
                .foregroundStyle(darkColor)
            Text("Permite el acceso para detectar tu respiración")
                .font(.custom("Poppins-Medium", size: 16))
                .foregroundStyle(darkColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var noCameraView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 48))
                .foregroundStyle(darkColor.opacity(0.5))
            Text("Cámara no disponible")
                .font(.custom("Poppins-Bold", size: 20))
                .foregroundStyle(darkColor)
        }
    }

    // MARK: - Computed Properties

    private var circleSize: CGFloat {
        120 + 80 * viewModel.breathingIntensity
    }

    private var phaseText: String {
        switch viewModel.breathingPhase {
        case .inhaling: return "Inhalando"
        case .exhaling: return "Exhalando"
        case .unknown:  return "Detectando..."
        }
    }

    private var phaseIcon: String {
        switch viewModel.breathingPhase {
        case .inhaling: return "arrow.up.circle.fill"
        case .exhaling: return "arrow.down.circle.fill"
        case .unknown:  return "circle.dotted"
        }
    }
}

#Preview {
    BreathDetectionView()
}
