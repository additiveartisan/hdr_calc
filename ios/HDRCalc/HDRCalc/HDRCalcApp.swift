import SwiftUI

@main
struct HDRCalcApp: App {
    private let hardware = StubCameraHardware()
    @State private var connectionService: CameraConnectionService
    @State private var shootingVM: ShootingViewModel

    init() {
        let hw = StubCameraHardware()
        _connectionService = State(initialValue: CameraConnectionService(hardware: hw))
        _shootingVM = State(initialValue: ShootingViewModel(hardware: hw))
        hardware = hw
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectionService)
                .environment(shootingVM)
        }
    }
}
