//
//  SituacionesView.swift
//  Copi
//
//  Created by Kxze on 06/05/26.
//

import SwiftUI

// MARK: - Model

struct Situacion: Identifiable, Hashable {
    let id = UUID()
    let titulo: String
}

// MARK: - SituacionesView

struct SituacionesView: View {

    @EnvironmentObject private var coordinator: ActivitySessionCoordinator

    // Opciones disponibles
    private let situaciones: [Situacion] = [
        Situacion(titulo: "Carga laboral"),
        Situacion(titulo: "Compañeros de trabajo"),
        Situacion(titulo: "Supervisores"),
        Situacion(titulo: "Situación familiar"),
    ]

    @State private var seleccionadas: Set<UUID> = []

    // MARK: - Colors
    private let fondoColor      = Color(red: 1.00, green: 0.98, blue: 0.94)   // blanco-crema (fondo general)
    private let tarjetaColor    = Color(red: 1.00, green: 0.96, blue: 0.87)   // crema claro (chips)
    private let tarjetaSelColor = Color(red: 0.93, green: 0.78, blue: 0.42)   // dorado suave (chip seleccionado)
    private let botonColor      = Color(red: 0.86, green: 0.68, blue: 0.25)   // dorado oscuro (botón)
    private let textoOscuro     = Color(red: 0.18, green: 0.24, blue: 0.32)   // azul oscuro (títulos)

    var body: some View {
        ZStack {
            fondoColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Pregunta ────────────────────────────────────────────
                Text("¿Qué situación detonó\neste sentimiento?")
                    .font(.custom("Poppins-Bold", size: 26))
                    .foregroundStyle(textoOscuro)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 40)

                // ── Opciones ────────────────────────────────────────────
                VStack(spacing: 16) {
                    ForEach(situaciones) { situacion in
                        SituacionChip(
                            titulo: situacion.titulo,
                            isSelected: seleccionadas.contains(situacion.id),
                            fondoNormal: tarjetaColor,
                            fondoSeleccionado: tarjetaSelColor,
                            textoColor: textoOscuro
                        ) {
                            toggleSeleccion(situacion.id)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // ── Botón Confirmar ─────────────────────────────────────
                Button {
                    if !seleccionadas.isEmpty {
                        coordinator.startSession()
                    }
                } label: {
                    Text("Confirmar")
                        .font(.custom("Poppins-SemiBold", size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            seleccionadas.isEmpty
                                ? botonColor.opacity(0.45)
                                : botonColor
                        )
                        .clipShape(Capsule())
                }
                .disabled(seleccionadas.isEmpty)
                .padding(.horizontal, 64)
                .animation(.easeInOut(duration: 0.2), value: seleccionadas.isEmpty)

                Spacer().frame(height: 48)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Helpers

    private func toggleSeleccion(_ id: UUID) {
        if seleccionadas.contains(id) {
            seleccionadas.remove(id)
        } else {
            seleccionadas.insert(id)
        }
    }
}

// MARK: - Chip Component

private struct SituacionChip: View {
    let titulo: String
    let isSelected: Bool
    let fondoNormal: Color
    let fondoSeleccionado: Color
    let textoColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(titulo)
                .font(.custom("Poppins-Regular", size: 17))
                .foregroundStyle(textoColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(isSelected ? fondoSeleccionado : fondoNormal)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? fondoSeleccionado : Color.clear,
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SituacionesView()
    }
}
