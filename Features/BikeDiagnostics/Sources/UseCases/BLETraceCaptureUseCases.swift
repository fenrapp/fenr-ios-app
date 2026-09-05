import BikeDomain

public struct StartNewBikeDiagnosticsCaptureUseCase: Sendable {
    private let repository: any BikeRepository

    public init(repository: any BikeRepository) {
        self.repository = repository
    }

    public func execute(vin: String) async -> Bool {
        await repository.startNewDiagnosticsCapture(vin: vin)
    }
}

public struct StopBikeDiagnosticsCaptureUseCase: Sendable {
    private let repository: any BikeRepository

    public init(repository: any BikeRepository) {
        self.repository = repository
    }

    public func execute() async -> Bool {
        await repository.stopDiagnosticsCapture()
    }
}
