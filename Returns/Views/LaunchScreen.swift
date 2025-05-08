//
//  LaunchScreen.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//


import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            // Background color
            Color("LaunchBackgroundColor")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App logo
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                
                // App name
                Text("Refund Radar")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Tagline
                Text("Stop losing your money.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct LaunchScreen_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreen()
    }
}
