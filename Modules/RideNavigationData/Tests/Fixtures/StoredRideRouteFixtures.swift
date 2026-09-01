import Foundation

enum StoredRideRouteFixtures {
    static let legacyRouteData = Data(
        #"""
        {
          "id": "00000000-0000-0000-0000-000000000201",
          "name": "Legacy route",
          "createdAt": "2023-11-14T22:13:20Z",
          "updatedAt": "2023-11-14T22:15:00Z",
          "segments": [
            {
              "id": "00000000-0000-0000-0000-000000000202",
              "points": [
                {
                  "latitude": 41.0,
                  "longitude": 2.0,
                  "elevationMeters": 120.0,
                  "timestamp": "2023-11-14T22:13:30Z",
                  "horizontalAccuracyMeters": 4.0
                }
              ]
            }
          ]
        }
        """#.utf8
    )

    static let invalidCoordinateData = Data(
        #"""
        {
          "id": "00000000-0000-0000-0000-000000000301",
          "name": "Invalid coordinate",
          "createdAt": 1700000000.125,
          "updatedAt": 1700000100.875,
          "segments": [
            {
              "id": "00000000-0000-0000-0000-000000000302",
              "points": [
                {
                  "latitude": 41.0,
                  "longitude": 2.0,
                  "elevationMeters": null,
                  "timestamp": null,
                  "horizontalAccuracyMeters": null
                },
                {
                  "latitude": 91.0,
                  "longitude": 2.0,
                  "elevationMeters": null,
                  "timestamp": null,
                  "horizontalAccuracyMeters": null
                }
              ]
            }
          ]
        }
        """#.utf8
    )
}
