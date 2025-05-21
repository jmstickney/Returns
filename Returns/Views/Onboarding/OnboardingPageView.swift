//
//  OnboardingPageView.swift
//  Returns
//
//  Created by Jonathan Stickney on 5/16/25.
//


// OnboardingPageView.swift
import SwiftUI

struct OnboardingPageView: View {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let backgroundColor: Color
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.white)
            
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 20)
            
            Spacer()
            Spacer()
        }
        .background(backgroundColor.opacity(0.8))
    }
}