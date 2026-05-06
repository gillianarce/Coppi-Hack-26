//
//  MecanicaTitle.swift
//  Copi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI

// MARK: - Data Model

/// Representa una categoría del juego con su nombre y color de acento.
struct GameCategory {
    let name: String
    let color: Color

    static let all: [GameCategory] = [
        GameCategory(name: "Animal",      color: Color(red: 0.93, green: 0.65, blue: 0.22)),
        GameCategory(name: "Fruta",       color: Color(red: 0.91, green: 0.36, blue: 0.36)),
        GameCategory(name: "País",        color: Color(red: 0.33, green: 0.72, blue: 0.55)),
        GameCategory(name: "Color",       color: Color(red: 0.45, green: 0.55, blue: 0.90)),
        GameCategory(name: "Comida",      color: Color(red: 0.93, green: 0.55, blue: 0.22)),
        GameCategory(name: "Nombre",      color: Color(red: 0.72, green: 0.38, blue: 0.80)),
        GameCategory(name: "Película",    color: Color(red: 0.22, green: 0.65, blue: 0.85)),
        GameCategory(name: "Profesión",   color: Color(red: 0.85, green: 0.40, blue: 0.60)),
        GameCategory(name: "Deporte",     color: Color(red: 0.30, green: 0.78, blue: 0.45)),
        GameCategory(name: "Objeto",      color: Color(red: 0.75, green: 0.60, blue: 0.30)),
    ]
}

/// Lista de letras del abecedario que se pueden sortear.
let alphabet: [String] = (65...90).map { String(UnicodeScalar($0)!) }  // "A" … "Z"

// MARK: - MecanicaTitle View

/// Muestra la instrucción principal del juego:
///   [prefix]           ← ej. "Nombra un"
///   [Categoría en color]
///   [suffix]           ← ej. "que comience con la letra…"
struct MecanicaTitle: View {

    var prefix: String
    var category: GameCategory
    var suffix: String

    init(
        prefix: String,
        category: GameCategory,
        suffix: String
    ) {
        self.prefix   = prefix
        self.category = category
        self.suffix   = suffix
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(prefix)
                .font(.custom("Poppins-Medium", size: 20))
                .foregroundStyle(Color(red: 0.25, green: 0.28, blue: 0.35))

            // Categoría — negrita y en color
            Text(category.name)
                .font(.custom("Poppins-Bold", size: 36))
                .foregroundStyle(category.color)

            Text(suffix)
                .font(.custom("Poppins-Medium", size: 20))
                .foregroundStyle(Color(red: 0.25, green: 0.28, blue: 0.35))
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        MecanicaTitle(
            prefix: "Nombra un",
            category: GameCategory.all[0], // Animal
            suffix: "que comience con la letra…"
        )
        MecanicaTitle(
            prefix: "Di una",
            category: GameCategory.all[1], // Fruta
            suffix: "que tenga más de 5 letras"
        )
        MecanicaTitle(
            prefix: "Menciona un",
            category: GameCategory.all[8], // Deporte
            suffix: "que se juegue en equipo"
        )
    }
    .padding()
}


