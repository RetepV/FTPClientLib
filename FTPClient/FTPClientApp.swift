//
//  FTPClientApp.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 15-10-2025.
//

import SwiftUI
import SwiftData

class ScreenSize: Sendable, Observable {
    let width: CGFloat
    let height: CGFloat
    
    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    init(size: CGSize) {
        self.width = size.width
        self.height = size.height
    }
}

@main
struct FTPClientApp: App {
    
    @State var screenSize: ScreenSize = .init(size: .zero)
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
