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
    case respiracion
    case colorGrading
    case breathDetection
}

// MARK: - Root Viewc

struct ContentView: View {
    @State private var path: [AppRoute] = []
    @State private var splashDone = false

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
            NavigationStack(path: $path) {
                MoodPickerView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .moodPicker:
                        MoodPickerView()
                    case .respiracion:
                        Respiracion478View()
                    case .colorGrading:
                        ColorGradingView()
                    case .breathDetection:
                        BreathDetectionView()
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
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
