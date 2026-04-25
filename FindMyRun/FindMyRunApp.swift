//
//  FindMyRunApp.swift
//  FindMyRun
//

import SwiftUI
import AppIntents

@main
struct FindMyRunApp: App {
    @State private var showSplash = true

    init() {
        FindMyRunShortcuts.updateAppShortcutParameters()
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showSplash {
                    SplashScreenView {
                        showSplash = false
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Splash Screen

private struct SplashScreenView: View {
    let onDismiss: () -> Void
    @State private var opacity: Double = 0
    @State private var iconScale: Double = 0.7
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.white, .red)
                    .scaleEffect(iconScale)

                Text("FindMyRun")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)

                Text("Discover group runs near you")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                iconScale = 1.0
                opacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onDismiss()
                }
            }
        }
    }
}
