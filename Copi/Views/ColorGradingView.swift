//
//  ColorGradingView.swift
//  Copi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI
import Lottie
struct ColorGradingView: View {
    var body: some View {
        ZStack{
            LottieView(animation:
            .named("1.2"))
            .playing()
            .looping()
            .resizable()
            .frame(width: 600)
            .offset(y:100)
            VStack{
            MecanicaTitle(
                prefix: "Nombra 5 objetos",
                category: GameCategory.all[0],
                suffix: "de tu entorno"
            )
            Text("1")
                    .font(.custom("Poppins-Bold", size: 110))
            Spacer()
           
        }
            .offset(y:50)
    }
}
}

#Preview {
    ColorGradingView()
}
