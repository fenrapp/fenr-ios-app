protocol AppStartupPreparing: Sendable {
    func prepare() async
}

struct NoOpAppStartupPreparer: AppStartupPreparing {
    func prepare() async {}
}
