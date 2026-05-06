//
//  AbrazaMariposView.swift
//  Copi
//
//  Created by Kxze on 06/05/26.
//

import SwiftUI
import Lottie

// MARK: - AbrazaMariposView

struct AbrazaMariposView: View {

    // MARK: - Color
    private let textoOscuro = Color(red: 0.18, green: 0.24, blue: 0.32)   // azul oscuro
    private let dorado      = Color(red: 0.93, green: 0.78, blue: 0.42)   // dorado suave

    var body: some View {
        ZStack {
            
            VStack(spacing: 0) {

                // ── Instrucción ─────────────────────────────────────────
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

                // ── Animación Lottie ────────────────────────────────────
                LottieView(animation: .named("2.3"))
                    .playing(loopMode: .autoReverse)
                    .resizable()
                    .frame(width: 600)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AbrazaMariposView()
    }
}
