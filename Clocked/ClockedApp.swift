//
//  ClockedApp.swift
//  Clocked
//
//  Created by Joab Bastidas on 5/4/26.
//

import SwiftUI
import CoreData

@main
struct ClockedApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
