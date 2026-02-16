import SwiftUI

@main
struct HDRCalcApp: App {
    @State private var connectionService: CameraConnectionService
    @State private var shootingVM: ShootingViewModel

    init() {
        let hardware = StubCameraHardware()
        _connectionService = State(initialValue: CameraConnectionService(hardware: hardware))
        _shootingVM = State(initialValue: ShootingViewModel(hardware: hardware))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectionService)
                .environment(shootingVM)
        }
    }
}
