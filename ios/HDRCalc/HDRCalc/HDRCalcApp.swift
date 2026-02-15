import SwiftUI

@main
struct HDRCalcApp: App {
    @State private var connectionService = CameraConnectionService()
    @State private var shootingVM = ShootingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectionService)
                .environment(shootingVM)
        }
    }
}
