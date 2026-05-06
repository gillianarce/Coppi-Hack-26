// MARK: - ChoqueTempView.swift
// Vista principal para la pantalla de "Choque de temperatura"
// Requiere: Lottie (pod 'lottie-ios') y la fuente Poppins en el proyecto

import SwiftUI
import Lottie

// MARK: - Componentes de Texto

/// Componente: "Lava tu rostro con"
struct LavaTuRostroText: View {
    var body: some View {
        Text("Lava tu rostro con")
            .font(.custom("Poppins-Regular", size: 20))
            .foregroundColor(Color(hex: "#4A4A4A"))
            .multilineTextAlignment(.center)
    }
}

/// Componente: "Agua fría" (destacado en amarillo/dorado)
struct AguaFriaText: View {
    var body: some View {
        Text("Agua fría")
            .font(.custom("Poppins-Bold", size: 32))
            .foregroundColor(Color(hex: "#E6A817"))
            .multilineTextAlignment(.center)
    }
}

/// Componente: "o sostén un hielo"
struct OSostenUnHieloText: View {
    var body: some View {
        Text("o sostén un hielo")
            .font(.custom("Poppins-Regular", size: 20))
            .foregroundColor(Color(hex: "#4A4A4A"))
            .multilineTextAlignment(.center)
    }
}

// MARK: - Componente de Animación Lottie

/// Componente: Animación Lottie con el archivo "3.1.json"
struct TemperatureAnimationView: UIViewRepresentable {
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: "3.1")
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.animationSpeed = 1.0
        animationView.play()
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}

// MARK: - Vista Principal

struct ChoqueTempView: View {
    @State private var animationWidth: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Sección de texto superior
            VStack(spacing: 4) {
                LavaTuRostroText()
                AguaFriaText()
                OSostenUnHieloText()
            }
            .padding(.top, 60)
            .padding(.horizontal, 32)

            Spacer()

            // MARK: Sección de animación inferior
            VStack(spacing: 12) {
                TemperatureAnimationView()
                    .scaledToFit()
                    .frame(width: animationWidth)

                // Control deslizante para ajustar el tamaño de la animación
                HStack {
                    Text("Tamaño")
                        .font(.custom("Poppins-Regular", size: 14))
                        .foregroundColor(Color(hex: "#4A4A4A"))
                    Slider(value: $animationWidth, in: 60...240)
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 0)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Color Extension (Hex)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    ChoqueTempView()
}//
//  AguaFria.swift
//  Copi
//
//  Created by Gillian Arce Cardenas on 06/05/26.
//


