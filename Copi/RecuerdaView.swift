//
//  RecuerdaView.swift
//  Copi
//
//  Created by Kxze on 06/05/26.
//

import SwiftUI

// MARK: - Tip Model

private struct RecuerdaTip: Identifiable {
    let id = UUID()

    enum Style {
        /// Texto plano, sin palabras destacadas
        case plain(String)
        /// Texto con una palabra/frase en dorado + resto del texto
        case highlighted(prefix: String, highlight: String, suffix: String)
        /// Texto con sección en negrita al final (como la captura 1)
        case boldSuffix(prefix: String, bold: String)
    }

    let style: Style
    /// Si `true`, muestra el botón de teléfono en la parte inferior
    let showPhone: Bool

    init(_ style: Style, showPhone: Bool = false) {
        self.style = style
        self.showPhone = showPhone
    }
}

// MARK: - Tips Data

private let tips: [RecuerdaTip] = [
    // ── Tipo 1: texto con parte en negrita ──────────────────────────────
    RecuerdaTip(
        .boldSuffix(
            prefix: "Ante la crisis recurre a los servicios de apoyo disponibles o comunícalo al ",
            bold: "Departamento de Bienestar Mental y Emocional."
        ),
        showPhone: true
    ),
    RecuerdaTip(
        .boldSuffix(
            prefix: "Si sientes que no puedes solo, pide ayuda. El apoyo está siempre disponible en el ",
            bold: "Departamento de Bienestar Mental y Emocional."
        ),
        showPhone: true
    ),
    RecuerdaTip(
        .boldSuffix(
            prefix: "No estás solo. Puedes hablar con alguien de confianza o acudir al ",
            bold: "Departamento de Bienestar Mental y Emocional."
        ),
        showPhone: true
    ),
    RecuerdaTip(
        .boldSuffix(
            prefix: "Reconocer que necesitas ayuda es un acto de valentía. Contáctanos en el ",
            bold: "Departamento de Bienestar Mental y Emocional."
        ),
        showPhone: true
    ),
    RecuerdaTip(
        .boldSuffix(
            prefix: "Hablar de cómo te sientes hace la diferencia. Acércate al ",
            bold: "Departamento de Bienestar Mental y Emocional."
        ),
        showPhone: true
    ),

    // ── Tipo 2: texto con palabra destacada en dorado ───────────────────
    RecuerdaTip(
        .highlighted(
            prefix: "Tomar ",
            highlight: "pausas breves",
            suffix: " para estirar e hidratarte, especialmente durante los periodos de mayor actividad."
        )
    ),
    RecuerdaTip(
        .highlighted(
            prefix: "Dormir bien es ",
            highlight: "fundamental",
            suffix: " para tu bienestar. Intenta respetar tus horas de descanso cada noche."
        )
    ),
    RecuerdaTip(
        .highlighted(
            prefix: "La ",
            highlight: "respiración consciente",
            suffix: " es una herramienta poderosa para reducir la ansiedad en momentos difíciles."
        )
    ),
    RecuerdaTip(
        .highlighted(
            prefix: "Mantener ",
            highlight: "conexiones sociales",
            suffix: " saludables con familia y amigos fortalece tu salud mental a largo plazo."
        )
    ),
    RecuerdaTip(
        .highlighted(
            prefix: "Celebra tus ",
            highlight: "pequeños logros",
            suffix: " diarios. Cada paso cuenta y te acerca a una mejor versión de ti mismo."
        )
    ),
]

// MARK: - RecuerdaView

struct RecuerdaView: View {
    @EnvironmentObject private var coordinator: ActivitySessionCoordinator

    private let textoOscuro = Color(red: 0.18, green: 0.24, blue: 0.32)
    private let dorado      = Color(red: 0.93, green: 0.78, blue: 0.42)
    private let phoneNumber = "8000204050"

    @State private var tipIndex: Int = 0

    private var currentTip: RecuerdaTip { tips[tipIndex] }

    var body: some View {
        VStack(spacing: 0) {

            // ── Dots indicator ──────────────────────────────────────────
            dotsIndicator
                .padding(.top, 56)

            // ── Title ───────────────────────────────────────────────────
            Text("Recuerda...")
                .font(.custom("Poppins-Bold", size: 26))
                .foregroundStyle(textoOscuro)
                .padding(.top, 28)

            // ── Tip body ────────────────────────────────────────────────
            tipText(currentTip)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .id(tipIndex) // forces re-render & animates on change
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .animation(.easeInOut(duration: 0.35), value: tipIndex)

            Spacer()

            // ── Bottom area ─────────────────────────────────────────────
            ZStack(alignment: .bottom) {
                CharacterFigure(color: dorado.opacity(0.75))
                    .frame(width: 260, height: 300)

                // Phone button (only on crisis tips)
                if currentTip.showPhone {
                    phoneButton
                        .padding(.bottom, 64)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        .animation(.easeInOut(duration: 0.3), value: currentTip.showPhone)
                }
            }

            // ── Caption ─────────────────────────────────────────────────
            Text("Coppel Contigo siempre al alcance")
                .font(.custom("Poppins-Regular", size: 13))
                .foregroundStyle(textoOscuro.opacity(0.55))
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .contentShape(Rectangle())
        .onTapGesture { advanceTip() }
    }

    // MARK: - Dots

    private var dotsIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dorado)
                .frame(width: 22, height: 22)
            Circle()
                .fill(dorado.opacity(0.5))
                .frame(width: 14, height: 14)
            Circle()
                .fill(dorado.opacity(0.3))
                .frame(width: 10, height: 10)
        }
    }

    // MARK: - Tip Text Builder

    @ViewBuilder
    private func tipText(_ tip: RecuerdaTip) -> some View {
        switch tip.style {
        case .plain(let text):
            Text(text)
                .font(.custom("Poppins-Regular", size: 18))
                .foregroundStyle(textoOscuro)

        case .highlighted(let prefix, let highlight, let suffix):
            let attributed: AttributedString = {
                var result = AttributedString()

                var prefixPart = AttributedString(prefix)
                prefixPart.font = .custom("Poppins-Regular", size: 18)
                prefixPart.foregroundColor = UIColor(textoOscuro)

                var highlightPart = AttributedString(highlight)
                highlightPart.font = .custom("Poppins-Bold", size: 18)
                highlightPart.foregroundColor = UIColor(dorado)

                var suffixPart = AttributedString(suffix)
                suffixPart.font = .custom("Poppins-Regular", size: 18)
                suffixPart.foregroundColor = UIColor(textoOscuro)

                result += prefixPart
                result += highlightPart
                result += suffixPart
                return result
            }()
            Text(attributed)

        case .boldSuffix(let prefix, let bold):
            let attributed: AttributedString = {
                var result = AttributedString()

                var prefixPart = AttributedString(prefix)
                prefixPart.font = .custom("Poppins-Regular", size: 18)
                prefixPart.foregroundColor = UIColor(textoOscuro)

                var boldPart = AttributedString(bold)
                boldPart.font = .custom("Poppins-Bold", size: 18)
                boldPart.foregroundColor = UIColor(textoOscuro)

                result += prefixPart
                result += boldPart
                return result
            }()
            Text(attributed)
        }
    }

    // MARK: - Phone Button

    private var phoneButton: some View {
        Button {
            callSupport()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.97, blue: 0.88))
                    .frame(width: 72, height: 72)
                    .shadow(color: dorado.opacity(0.35), radius: 12, y: 4)

                Image(systemName: "phone.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(textoOscuro)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func advanceTip() {
        let next = tipIndex + 1
        if next < tips.count {
            withAnimation { tipIndex = next }
        } else {
            coordinator.advance()
        }
    }

    private func callSupport() {
        guard let url = URL(string: "tel://\(phoneNumber)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Character Figure

/// A golden circle sitting on a narrow triangle, matching the reference design.
private struct CharacterFigure: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Circle takes ~70 % of the width; triangle fills the bottom ~35 %
            let circleSize  = w * 0.88
            let neckWidth   = w * 0.30
            let triangleH   = h * 0.35

            ZStack(alignment: .bottom) {
                // ── Triangle (neck/body) ────────────────────────────────
                Triangle()
                    .fill(color)
                    .frame(width: neckWidth, height: triangleH)

                // ── Circle (head) ───────────────────────────────────────
                Circle()
                    .fill(color)
                    .frame(width: circleSize, height: circleSize)
                    // Overlap the triangle slightly so they feel connected
                    .offset(y: -(triangleH * 0.55))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// Upward-pointing triangle used as the character's body/neck.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            // Base at the bottom, apex at the top-center
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecuerdaView()
    }
    .environmentObject(ActivitySessionCoordinator())
}
