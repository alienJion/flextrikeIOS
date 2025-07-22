//
//  opencvtestminimalApp.swift
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/22.
//

import SwiftUI

@main
struct flextargetApp: App {
    @State private var showLaunchScreen = true
    @StateObject var bleManager = BLEManager()

    var body: some Scene {
        WindowGroup {
            if showLaunchScreen {
                LaunchScreen()
                    .onAppear {
                        // Hide launch screen after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showLaunchScreen = false
                            }
                        }
                    }
            } else {
                /*OrientationView() */ // Replace with your main view
                AddDrillConfigView()
            }
        }
    }
}



