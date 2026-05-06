//
//  CopiApp.swift
//  Copi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI
import AppIntents

@main
struct CopiApp: App {

    init() {
        // Registra las frases de Siri al instalar / actualizar la app
        CopiShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
