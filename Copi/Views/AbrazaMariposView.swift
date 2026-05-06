//
//  AbrazaMariposView.swift
//  Copi
//
//  Created by Kxze on 06/05/26.
//

import SwiftUI
import Combine
import AVFoundation
import Vision
import Lottie

// MARK: - Hug Phase

private enum HugPhase {
    case waiting
    case approaching
    case hugging
}

// MARK: - Detected Joints

private struct ArmJoints {
    let neck: CGPoint
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    let leftElbow: CGPoint
    let rightElbow: CGPoint
    let leftWrist: CGPoint
    let rightWrist: CGPoint
}

// MARK: - Hug Camera Manager

private final class HugCameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.copi.hug.vision", qos: .userInitiated)

    var onPoseDetected: ((ArmJoints) -> Void)?

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

extension HugCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

        do {
            try handler.perform([request])
            guard let results = request.results as? [VNHumanBodyPoseObservation],
                  let observation = results.first else { return }

            let minConf: Float = 0.2
            let neck = try observation.recognizedPoint(.neck)
            let lShoulder = try observation.recognizedPoint(.leftShoulder)
            let rShoulder = try observation.recognizedPoint(.rightShoulder)
            let lElbow = try observation.recognizedPoint(.leftElbow)
            let rElbow = try observation.recognizedPoint(.rightElbow)
            let lWrist = try observation.recognizedPoint(.leftWrist)
            let rWrist = try observation.recognizedPoint(.rightWrist)

            guard neck.confidence > minConf,
                  lShoulder.confidence > minConf,
                  rShoulder.confidence > minConf,
                  lWrist.confidence > minConf,
                  rWrist.confidence > minConf else { return }

            let joints = ArmJoints(
                neck: neck.location,
                leftShoulder: lShoulder.location,
                rightShoulder: rShoulder.location,
                leftElbow: lElbow.location,
                rightElbow: rElbow.location,
                leftWrist: lWrist.location,
                rightWrist: rWrist.location
            )

            onPoseDetected?(joints)
        } catch {}
    }
}

// MARK: - Hug ViewModel

private final class HugViewModel: ObservableObject {
    @Published var phase: HugPhase = .waiting
    @Published var tapCount: Int = 0
    @Published var isDetecting = false
    @Published var holdSeconds: Int = 0
    @Published var exerciseComplete = false

    private var wristDiffBuffer: [CGFloat] = []
    private let bufferSize = 15
    private var lastPeakWasUp = false
    private var holdTimer: Timer?
    private let targetHoldSeconds = 30

    func processJoints(_ joints: ArmJoints) {
        DispatchQueue.main.async { [weak self] in
            self?.update(with: joints)
        }
    }

    func stop() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func update(with joints: ArmJoints) {
        let bodyMidX = (joints.leftShoulder.x + joints.rightShoulder.x) / 2
        let shoulderWidth = abs(joints.leftShoulder.x - joints.rightShoulder.x)

        guard shoulderWidth > 0.01 else {
            isDetecting = false
            return
        }

        isDetecting = true

        // Front camera: person's left shoulder typically has higher X value.
        // "Crossed" = left wrist moved toward lower X, right wrist toward higher X.
        let crossMargin = shoulderWidth * 0.15
        let leftWristCrossed  = joints.leftWrist.x < bodyMidX + crossMargin
        let rightWristCrossed = joints.rightWrist.x > bodyMidX - crossMargin

        // Wrists at chest height (near shoulder Y level)
        let shoulderMidY = (joints.leftShoulder.y + joints.rightShoulder.y) / 2
        let heightTolerance = shoulderWidth * 1.2
        let leftAtChest  = abs(joints.leftWrist.y - shoulderMidY) < heightTolerance
        let rightAtChest = abs(joints.rightWrist.y - shoulderMidY) < heightTolerance

        // Wrists close together (not spread out)
        let wristSpan = abs(joints.leftWrist.x - joints.rightWrist.x)
        let wristsClose = wristSpan < shoulderWidth * 0.9

        let newPhase: HugPhase
        if leftWristCrossed && rightWristCrossed && leftAtChest && rightAtChest && wristsClose {
            newPhase = .hugging
        } else if (leftWristCrossed || rightWristCrossed) && (leftAtChest || rightAtChest) {
            newPhase = .approaching
        } else {
            newPhase = .waiting
        }

        if newPhase == .hugging && phase != .hugging {
            startHoldTimer()
        } else if newPhase != .hugging && phase == .hugging {
            holdTimer?.invalidate()
            holdTimer = nil
        }

        if newPhase == .hugging {
            detectTaps(leftWristY: joints.leftWrist.y, rightWristY: joints.rightWrist.y)
        } else {
            wristDiffBuffer.removeAll()
        }

        phase = newPhase
    }

    private func startHoldTimer() {
        holdSeconds = 0
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.holdSeconds += 1
            if self.holdSeconds >= self.targetHoldSeconds {
                self.exerciseComplete = true
                self.holdTimer?.invalidate()
                self.holdTimer = nil
            }
        }
    }

    // Detect alternating tapping by tracking the Y-difference between wrists.
    // Each peak → valley cycle counts as one tap.
    private func detectTaps(leftWristY: CGFloat, rightWristY: CGFloat) {
        let diff = leftWristY - rightWristY
        wristDiffBuffer.append(diff)
        if wristDiffBuffer.count > bufferSize { wristDiffBuffer.removeFirst() }

        guard wristDiffBuffer.count >= 4 else { return }

        let n = wristDiffBuffer.count
        let prevPrev = wristDiffBuffer[n - 3]
        let prev     = wristDiffBuffer[n - 2]
        let curr     = wristDiffBuffer[n - 1]
        let threshold: CGFloat = 0.004

        let isPeak   = prev > prevPrev + threshold && prev > curr + threshold
        let isValley = prev < prevPrev - threshold && prev < curr - threshold

        if isPeak && !lastPeakWasUp {
            tapCount += 1
            lastPeakWasUp = true
        } else if isValley && lastPeakWasUp {
            lastPeakWasUp = false
        }
    }

    deinit {
        holdTimer?.invalidate()
    }
}

// MARK: - Camera Preview

private struct HugCameraPreview: UIViewRepresentable {
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

// MARK: - AbrazaMariposView

struct AbrazaMariposView: View {
    @StateObject private var cameraManager = HugCameraManager()
    @StateObject private var viewModel = HugViewModel()

    private let textoOscuro = Color(red: 0.18, green: 0.24, blue: 0.32)
    private let dorado      = Color(red: 0.93, green: 0.78, blue: 0.42)

    var body: some View {
        ZStack {
            if cameraManager.permissionGranted {
                HugCameraPreview(session: cameraManager.captureSession)
                    .ignoresSafeArea()

                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                if viewModel.exerciseComplete {
                    completionContent
                } else {
                    mainContent
                }
            } else {
                fallbackContent
            }
        }
        .onAppear {
            cameraManager.onPoseDetected = { joints in
                viewModel.processJoints(joints)
            }
            cameraManager.checkPermission()
        }
        .onDisappear {
            cameraManager.onPoseDetected = nil
            viewModel.stop()
            cameraManager.stopSession()
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Main Content (detection active)

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Instruction
            VStack(spacing: 4) {
                Text("Cruza los brazos sobre el\npecho en posición de")
                    .font(.custom("Poppins-Regular", size: 22))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Abrazo Mariposa")
                    .font(.custom("Poppins-Bold", size: 26))
                    .foregroundStyle(dorado)
            }
            .padding(.top, 64)

            Spacer()

            // Detection indicator
            ZStack {
                // Progress ring (30 seconds target)
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 8)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(dorado, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: holdProgress)

                // Inner circle
                Circle()
                    .fill(phaseColor.opacity(0.25))
                    .frame(width: 155, height: 155)
                    .animation(.easeInOut(duration: 0.4), value: viewModel.phase)

                VStack(spacing: 8) {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(phaseColor)
                        .contentTransition(.symbolEffect(.replace))

                    Text(phaseText)
                        .font(.custom("Poppins-Bold", size: 16))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }

            // Stats (visible while hugging)
            if viewModel.phase == .hugging {
                VStack(spacing: 8) {
                    Text("\(viewModel.holdSeconds)s")
                        .font(.custom("Poppins-Bold", size: 40))
                        .foregroundStyle(dorado)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.holdSeconds)

                    if viewModel.tapCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .foregroundStyle(dorado)
                            Text("\(viewModel.tapCount) taps")
                                .font(.custom("Poppins-Medium", size: 16))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.top, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            Spacer()

            // Lottie animation as reference guide
            LottieView(animation: .named("2.3"))
                .playing(loopMode: .autoReverse)
                .resizable()
                .frame(width: 240, height: 170)
                .opacity(0.6)
                .padding(.bottom, 16)
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.4), value: viewModel.phase)
    }

    // MARK: - Completion

    private var completionContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 70))
                .foregroundStyle(dorado)

            Text("¡Ejercicio completado!")
                .font(.custom("Poppins-Bold", size: 28))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Mantuviste el abrazo por \(viewModel.holdSeconds) segundos")
                    .font(.custom("Poppins-Medium", size: 16))
                    .foregroundStyle(.white.opacity(0.8))

                if viewModel.tapCount > 0 {
                    Text("Realizaste \(viewModel.tapCount) taps")
                        .font(.custom("Poppins-Medium", size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Fallback (no camera)

    private var fallbackContent: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
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

                Spacer()

                LottieView(animation: .named("2.3"))
                    .playing(loopMode: .autoReverse)
                    .resizable()
                    .frame(width: 600)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Computed Properties

    private var holdProgress: CGFloat {
        min(CGFloat(viewModel.holdSeconds) / CGFloat(30), 1.0)
    }

    private var phaseColor: Color {
        switch viewModel.phase {
        case .waiting:     return .white
        case .approaching: return .orange
        case .hugging:     return dorado
        }
    }

    private var phaseIcon: String {
        switch viewModel.phase {
        case .waiting:     return "person.crop.rectangle"
        case .approaching: return "hand.raised.fill"
        case .hugging:     return "checkmark.circle.fill"
        }
    }

    private var phaseText: String {
        if !viewModel.isDetecting {
            return "Colócate frente\na la cámara"
        }
        switch viewModel.phase {
        case .waiting:     return "Cruza los brazos"
        case .approaching: return "¡Casi! Acerca más"
        case .hugging:     return "¡Abrazo detectado!"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AbrazaMariposView()
    }
}
