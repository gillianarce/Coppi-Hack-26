//
//  CoordinatorStore.swift
//  Copi
//
//  Created by Kxze on 06/05/26.
//

import Foundation

// MARK: - CoordinatorStore

/// Singleton que mantiene una referencia débil al ActivitySessionCoordinator
/// activo. Permite que los AppIntents (que viven fuera del árbol SwiftUI)
/// puedan disparar navegación dentro de la app.
@MainActor
final class CoordinatorStore {

    static let shared = CoordinatorStore()
    private init() {}

    // Referencia al coordinator inyectado desde ContentView
    weak var coordinator: ActivitySessionCoordinator?

    // MARK: - Acciones de navegación

    /// Navega directamente a la pantalla del Journal.
    /// Si ya hay rutas apiladas, las reemplaza para ir directo.
    func openJournal() {
        coordinator?.path = [AppRoute.journal]
    }

    /// Navega a la pantalla de Respiración 4-7-8.
    func openRespiracion() {
        coordinator?.path = [AppRoute.respiracion]
    }

    /// Navega a la pantalla de Abraza Mariposa.
    func openAbrazaMariposa() {
        coordinator?.path = [AppRoute.abrazaMariposa]
    }

    /// Navega a la mecánica de letras.
    func openMecanica() {
        coordinator?.path = [AppRoute.mecanica]
    }
}
