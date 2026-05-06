//
//  ContentView.swift
//  Copi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI

// MARK: - App Route

enum AppRoute: Hashable {
    case moodPicker
    case situaciones
    case respiracion
    case colorGrading
    case breathDetection
    case journal
    case abrazaMariposa
    case recuerda
    case mecanica
}

// MARK: - Root View

struct ContentView: View {
    @State private var splashDone = false
    @StateObject private var coordinator = ActivitySessionCoordinator()

    var body: some View {
        if !splashDone {
            // ── Splash ──────────────────────────────────────────────────
            SplashView()
                .onTapGesture { advanceFromSplash() }
                .onAppear {
                    // Avanza automáticamente tras 6 s (un ciclo inhala/exhala)
                    Task {
                        try? await Task.sleep(for: .seconds(6))
                        advanceFromSplash()
                    }
                }
        } else {
            // ── Flujo principal ─────────────────────────────────────────
            NavigationStack(path: $coordinator.path) {
                MoodPickerView(path: $coordinator.path)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .moodPicker:
                            MoodPickerView(path: $coordinator.path)
                        case .situaciones:
                            SituacionesView()
                        case .respiracion:
                            Respiracion478View()
                        case .colorGrading:
                            ColorGradingView()
                        case .breathDetection:
                            BreathDetectionView()
                        case .journal:
                            JournalView()
                        case .abrazaMariposa:
                            AbrazaMariposView()
                        case .recuerda:
                            RecuerdaView()
                        case .mecanica:
                            MecanicaTitleView()
                        }
                    }
            }
            .navigationBarBackButtonHidden(true)
            // Inyectar el coordinator a todo el árbol de vistas
            .environmentObject(coordinator)
            // ── Conectar el coordinator al store para AppIntents ─────────
            .onAppear {
                CoordinatorStore.shared.coordinator = coordinator
            }
        }
    }

    private func advanceFromSplash() {
        guard !splashDone else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            splashDone = true
        }
    }
}

#Preview {
    ContentView()
}
