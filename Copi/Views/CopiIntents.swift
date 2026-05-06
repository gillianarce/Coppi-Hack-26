//
//  CopiIntents.swift
//  Copi
//
//  Created by Kxze on 06/05/26.
//

import AppIntents
import SwiftUI

// MARK: - Abrir Journal

struct AbrirJournalIntent: AppIntent {

    static var title: LocalizedStringResource = "Abrir Journal"
    static var description = IntentDescription(
        "Abre la pantalla de journal en Copi para que puedas escribir cómo te sientes."
    )

    // La app debe abrirse al frente antes de ejecutarse
    static var supportedModes: IntentModes = [.foreground(.immediate)]

    @MainActor
    func perform() async throws -> some IntentResult {
        CoordinatorStore.shared.openJournal()
        return .result()
    }
}

// MARK: - Abrir Respiración

struct AbrirRespiracionIntent: AppIntent {

    static var title: LocalizedStringResource = "Abrir Respiración"
    static var description = IntentDescription(
        "Abre el ejercicio de respiración 4-7-8 en Copi para ayudarte a relajarte."
    )

    static var supportedModes: IntentModes = [.foreground(.immediate)]

    @MainActor
    func perform() async throws -> some IntentResult {
        CoordinatorStore.shared.openRespiracion()
        return .result()
    }
}

// MARK: - Abrir Abraza Mariposa

struct AbrirAbrazaMariposIntent: AppIntent {

    static var title: LocalizedStringResource = "Abraza Mariposa"
    static var description = IntentDescription(
        "Abre el ejercicio de abrazo mariposa en Copi para calmarte."
    )

    static var supportedModes: IntentModes = [.foreground(.immediate)]

    @MainActor
    func perform() async throws -> some IntentResult {
        CoordinatorStore.shared.openAbrazaMariposa()
        return .result()
    }
}

// MARK: - Abrir Mecánica de letras

struct AbrirMecanicaIntent: AppIntent {

    static var title: LocalizedStringResource = "Juego de letras"
    static var description = IntentDescription(
        "Abre el juego de letras en Copi para ejercitar tu mente."
    )

    static var supportedModes: IntentModes = [.foreground(.immediate)]

    @MainActor
    func perform() async throws -> some IntentResult {
        CoordinatorStore.shared.openMecanica()
        return .result()
    }
}

// MARK: - App Shortcuts (frases para Siri)

struct CopiShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        AppShortcut(
            intent: AbrirJournalIntent(),
            phrases: [
                "Abre mi journal en \(.applicationName)",
                "Abrir journal en \(.applicationName)",
                "Ir al journal de \(.applicationName)",
                "Quiero escribir en \(.applicationName)",
                "Quiero contarle algo a \(.applicationName)"
            ],
            shortTitle: "Abrir Journal",
            systemImageName: "book.fill"
        )

        AppShortcut(
            intent: AbrirRespiracionIntent(),
            phrases: [
                "Abre la respiración en \(.applicationName)",
                "Quiero respirar con \(.applicationName)",
                "Ejercicio de respiración en \(.applicationName)"
            ],
            shortTitle: "Respiración 4-7-8",
            systemImageName: "wind"
        )

        AppShortcut(
            intent: AbrirAbrazaMariposIntent(),
            phrases: [
                "Abraza mariposa en \(.applicationName)",
                "Quiero calmarme con \(.applicationName)",
                "Abre abraza mariposa en \(.applicationName)"
            ],
            shortTitle: "Abraza Mariposa",
            systemImageName: "hands.sparkles.fill"
        )

        AppShortcut(
            intent: AbrirMecanicaIntent(),
            phrases: [
                "Abre el juego de letras en \(.applicationName)",
                "Jugar letras con \(.applicationName)",
                "Quiero jugar en \(.applicationName)"
            ],
            shortTitle: "Juego de letras",
            systemImageName: "textformat.abc"
        )
    }
}
