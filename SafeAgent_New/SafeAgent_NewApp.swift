//
//  SafeAgent_NewApp.swift
//  SafeAgent_New
//
//  Created by Robert Backus on 5/10/25.
//

import SwiftUI

@main
struct SafeAgent_NewApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
