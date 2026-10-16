//
//  TaskManagerApp.swift
//  TaskManager
//
//  Created by Sofiia on 21.09.2026.
//

import SwiftUI

@main
struct TaskManagerApp: App {
    // Власник ViewModel і Router — застосунок; конкретні залежності збирає AppEnvironment.
    @StateObject private var viewModel = AppEnvironment.makeViewModel()
    @StateObject private var router = AppEnvironment.makeRouter()
    @StateObject private var serverTasks = AppEnvironment.makeServerTasksViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, router: router, serverTasks: serverTasks)
        }
    }
}
