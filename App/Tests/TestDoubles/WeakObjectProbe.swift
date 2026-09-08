@MainActor
final class WeakObjectProbe {
    let name: String
    private(set) weak var object: AnyObject?

    init(name: String, object: AnyObject) {
        self.name = name
        self.object = object
    }
}
