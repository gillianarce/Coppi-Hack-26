//
//  MoodPickerView.swift
//  Coppi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI

// MARK: - Model

struct Mood: Identifiable {
    let id = UUID()
    let name: String      // también es el nombre del asset
    let label: String     // texto que se muestra debajo
}

private let moods: [Mood] = [
    Mood(name: "agotado",   label: "Agotado"),
    Mood(name: "enojado",   label: "Enojado"),
    Mood(name: "triste",    label: "Triste"),
    Mood(name: "tranquilo", label: "Tranquilo"),
    Mood(name: "seguro",  label: "Seguro"),
    Mood(name: "alegre",    label: "Alegre"),
    Mood(name: "feliz",  label: "Feliz"),
]

// MARK: - Arc Carousel

/// Distribuye `items` en arco. El item central está al frente y más grande.
private struct ArcCarousel: View {
    let moods: [Mood]
    @Binding var selectedIndex: Int

    // Geometría del arco
    private let arcRadius: CGFloat = 320
    // Cuántos grados ocupa el arco total visible
    private let totalArcDegrees: CGFloat = 160
    // Tamaño base de cada tarjeta
    private let cardSize: CGFloat = 130

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2,
                                 y: geo.size.height + arcRadius * 0.52)

            ZStack {
                ForEach(Array(moods.enumerated()), id: \.element.id) { index, mood in
                    let angle = angleFor(index: index)
                    let rad   = angle * .pi / 180
                    let x     = center.x + arcRadius * sin(rad)
                    let y     = center.y - arcRadius * cos(rad)

                    let distance  = abs(CGFloat(index - selectedIndex))
                    let scale     = max(0.6, 1.0 - distance * 0.13)
                    let opacity   = max(0.35, 1.0 - distance * 0.22)
                    let isCenter  = index == selectedIndex

                    MoodCard(mood: mood, isSelected: isCenter, cardSize: cardSize)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .position(x: x, y: y)
                        .zIndex(isCenter ? 1 : 0)
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.4)) {
                                selectedIndex = index
                            }
                        }
                }
            }
            // Drag gesture para deslizar el carrusel
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let threshold: CGFloat = 40
                        if value.translation.width < -threshold {
                            withAnimation(.snappy(duration: 0.35)) {
                                selectedIndex = min(selectedIndex + 1, moods.count - 1)
                            }
                        } else if value.translation.width > threshold {
                            withAnimation(.snappy(duration: 0.35)) {
                                selectedIndex = max(selectedIndex - 1, 0)
                            }
                        }
                    }
            )
        }
    }

    // Ángulo en grados para el item `index`, centrado en el item seleccionado
    private func angleFor(index: Int) -> CGFloat {
        let count   = CGFloat(moods.count)
        let step    = totalArcDegrees / max(count - 1, 1)
        let offset  = CGFloat(index - selectedIndex)
        return offset * step
    }
}

// MARK: - Mood Card

private struct MoodCard: View {
    let mood: Mood
    let isSelected: Bool
    let cardSize: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Fondo de la tarjeta
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected
                          ? Color(red: 0.99, green: 0.85, blue: 0.51)   // amarillo del círculo
                          : Color.white.opacity(0.15))
                    .frame(width: cardSize, height: cardSize)
                    .shadow(color: isSelected ? Color(red: 0.99, green: 0.85, blue: 0.51).opacity(0.5) : .clear,
                            radius: 16, y: 6)

                Image(mood.name)
                    .resizable()
                    .scaledToFit()
                    .padding(14)
                    .frame(width: cardSize, height: cardSize)
            }

            Text(mood.label)
                .font(.custom("Poppins-Bold", size: isSelected ? 30 : 12))
                .foregroundStyle(.black)
                .opacity(isSelected ? 1.0 : 0.55)
        }
    }
}

// MARK: - Mood Picker View

struct MoodPickerView: View {
    @State private var selectedIndex: Int = 3   // empieza en el centro (disperso)

    var body: some View {
        GeometryReader { geo in
            let screenWidth  = geo.size.width
            let screenHeight = geo.size.height

            ZStack {
                // Fondo — mismo color que SplashView
                

                VStack(spacing: 0) {
                    Spacer()
                    // — Encabezado
                    VStack(spacing: 8) {
                        Text("¿Cómo te sientes hoy?")
                            .font(.custom("Poppins-Bold", size: 26))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, screenHeight * 0.08)
                    .padding(.horizontal, 32)

                    // — Carrusel en arco
                    ArcCarousel(moods: moods, selectedIndex: $selectedIndex)
                        .frame(width: screenWidth, height: screenHeight * 0.46)

                    Spacer()

                    // — Botón de confirmación
                    Button {
                        // acción al confirmar
                    } label: {
                        Text("Confirmar")
                            .font(.custom("Poppins-Bold", size: 18))
                            .foregroundStyle(.white)
                            .padding(20)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.99, green: 0.85, blue: 0.51))
                                    .shadow(color: Color(red: 0.99, green: 0.85, blue: 0.51).opacity(0.45),
                                            radius: 12, y: 4)
                            )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, screenHeight * 0.07)
                }
            }
        }
    }
}

#Preview {
    MoodPickerView()
}
