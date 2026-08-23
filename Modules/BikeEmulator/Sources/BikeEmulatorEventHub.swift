import AsyncSupport

typealias BikeEmulatorEventHub<Value: Sendable> = AsyncSupport.AsyncEventHub<Value>
