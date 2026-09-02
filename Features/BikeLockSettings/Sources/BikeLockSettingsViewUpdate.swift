enum BikeLockSettingsViewUpdate<Value> {
    case preserve
    case set(Value)

    func resolve(previous: Value) -> Value {
        switch self {
        case .preserve: previous
        case .set(let value): value
        }
    }
}
