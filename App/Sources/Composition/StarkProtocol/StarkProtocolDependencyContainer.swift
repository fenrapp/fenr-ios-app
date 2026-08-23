import StarkProtocol

struct StarkProtocolDependencyContainer {
    func makeAuthenticationPayloadBuilder() -> any StarkAuthenticationPayloadBuilding {
        StarkAuthenticationPayloadBuilder()
    }
}
