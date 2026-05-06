//
//  MecanicaTitleView.swift
//  Coppi
//
//  Created by Kxze on 05/05/26.
//

import SwiftUI
import Lottie

struct MecanicaTitleView: View {
    var body: some View {
            ZStack{
                LottieView(animation:
                .named("1.1"))
                .playing()
                .looping()
                .resizable()
                .frame(width: 600)
                .offset(y:100)
                VStack{
                MecanicaTitle(
                    prefix: "Nombra un",
                    category: GameCategory.all[0],
                    suffix: "que comience con la letra…"
                )
                Text("A")
                        .font(.custom("Poppins-Bold", size: 110))
                Spacer()
               
            }
                .offset(y:50)
        }
    }
}

#Preview {
    MecanicaTitleView()
}
