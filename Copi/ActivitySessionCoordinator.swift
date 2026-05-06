//
//  ActivitySessionCoordinator.swift
//  Copi
//
//  Created by Kxze on 06/05/26.
//

import Combine
import SwiftUI

// MARK: - Activity Session Coordinator

/// Define la secuencia de pantallas de actividad y coordina las transiciones
/// entre ellas. Se inyecta como EnvironmentObject desde ContentView para que
/// cualquier pantalla del flujo pueda llamar `advance()` sin necesitar
/// acceso directo al `NavigationPath`.
@MainActor
final class ActivitySessionCoordinator: ObservableObject {

    // El path del NavigationStack es propiedad del coordinator,
    // ContentView lo enlaza con $coordinator.path.
    @Published var path: [AppRoute] = []

    // La secuencia de rutas que componen una sesión completa.
    private static let activitySequence: [AppRoute] = [
        .mecanica,
        .abrazaMariposa,
        .journal,
        .recuerda,
    ]

    // Índice de la actividad actual dentro de `activitySequence`.
    // -1 significa que la sesión aún no ha comenzado.
    private var currentActivityIndex: Int = -1

    // MARK: - API pública

    /// Inicia la sesión desde el principio, empujando la primera actividad.
    func startSession() {
        currentActivityIndex = 0
        pushCurrent()
    }

    /// Avanza a la siguiente actividad de la sesión.
    /// Si ya se completaron todas, limpia el stack (regresa al inicio).
    func advance() {
        currentActivityIndex += 1

        if currentActivityIndex < Self.activitySequence.count {
            pushCurrent()
        } else {
            // Sesión completada: regresa a la raíz
            finishSession()
        }
    }

    /// Cancela la sesión y vuelve a la raíz.
    func finishSession() {
        currentActivityIndex = -1
        path.removeAll()
    }

    // MARK: - Privado

    private func pushCurrent() {
        guard currentActivityIndex < Self.activitySequence.count else { return }
        let route = Self.activitySequence[currentActivityIndex]
        path.append(route)
    }
}

