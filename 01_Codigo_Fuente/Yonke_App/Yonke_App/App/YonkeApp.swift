import SwiftUI

@main
struct YonkeApp: App {
    var body: some Scene {
        WindowGroup {
            AppRouter() // Asegúrate de que llame a tu vista principal
        }
    }
}
