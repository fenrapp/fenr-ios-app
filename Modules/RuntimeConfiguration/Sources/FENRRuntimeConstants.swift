import Foundation

public enum FENRRuntimeConstants {
    public enum LiveActivity {
        public static let completeBatteryPercent = 100
        public static let chargingUpdateInterval: TimeInterval = 30
    }

    public enum Telemetry {
        public static let freshnessInterval: TimeInterval = 30
        public static let statusSnapshotRefreshInterval: Duration = .milliseconds(125)
    }

    public enum RideDashboard {
        public static let reconnectionGracePeriod: Duration = .seconds(30)
        public static let clockRefreshInterval: TimeInterval = 60
        public static let deviceSpeedMaximumSampleAge: TimeInterval = 3
    }

    public enum BatteryHealth {
        public static let renderInterval: Duration = .milliseconds(250)
    }

    public enum Onboarding {
        public static let bluetoothPermissionResponseTimeout: Duration = .seconds(10)
    }

    public enum BikeSDK {
        public static let backgroundModesInfoPlistKey = "UIBackgroundModes"
        public static let bluetoothCentralBackgroundMode = "bluetooth-central"
        public static let centralRestorationIdentifier = "com.fenr.app.ble-central"
        public static let notificationDebugMinimumInterval: TimeInterval = 1
        public static let securityOperationTimeout: Duration = .seconds(10)
        public static let subscriptionOperationTimeout: Duration = .seconds(8)
        public static let reconnectDelays: [Duration] = [
            .seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(15)
        ]
    }

    public enum Emulator {
        public static let updateInterval: Duration = .milliseconds(400)
    }

    public enum Environment {
        public static let debugDeviceSpeedUpdateInterval: Duration = .seconds(1)
    }
}
