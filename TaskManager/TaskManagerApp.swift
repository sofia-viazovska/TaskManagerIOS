//
//  TaskManagerApp.swift
//  TaskManager
//
//  Created by Sofiia on 21.09.2026.
//

import SwiftUI

@main
struct TaskManagerApp: App {
    // Власник ViewModel — застосунок; конкретні залежності збирає AppEnvironment.
    @StateObject private var viewModel = AppEnvironment.makeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
