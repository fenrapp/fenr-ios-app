struct DashboardPresentationCache<Input: Equatable, Value> {
    private var entry: (input: Input, value: Value)?

    mutating func value(for input: Input, makeValue: () -> Value) -> Value {
        if let entry, entry.input == input { return entry.value }
        let value = makeValue()
        entry = (input, value)
        return value
    }
}
