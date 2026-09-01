public struct RideNavigationViewState: Equatable, Sendable {
    public enum Screen: Equatable, Sendable {
        case home
        case map
        case summary
    }

    public enum Activity: Equatable, Sendable {
        case preview
        case following
        case navigating
        case recording
        case paused
    }

    public let screen: Screen
    public let activity: Activity
    public let mapScene: NavigationMapScene
    public let mapSources: [MapSourceDescriptor]
    public let selectedMapStyleID: String
    public let allowsFocusMapStyle: Bool
    public let isHeadingUp: Bool
    public let speedText: String
    public let speedUnit: String
    public let modeText: String
    public let batteryText: String
    public let elapsedText: String
    public let distanceText: String
    public let guidance: RideNavigationGuidance?
    public let routeTitle: String?
    public let savedRoutes: [RideNavigationRouteRow]
    public let searchQuery: String
    public let searchResults: [RideNavigationSearchResult]
    public let roadRouteOptions: [RideNavigationRoadRouteOption]
    public let avoidsTolls: Bool
    public let avoidsHighways: Bool
    public let showsRoadRoutePreferences: Bool
    public let isCalculatingRoadRoutes: Bool
    public let isPreparingTrail: Bool
    public let isRerouting: Bool
    public let isSearching: Bool
    public let errorText: String?
    public let isVoiceMuted: Bool
    public let canReverseRoute: Bool
    public let canMinimize: Bool
    public let canFindTrailExit: Bool
    public let canResumeGPX: Bool
    public let isFindingTrailExit: Bool
    public let trailExitPreview: RideNavigationTrailExitPreview?
    public let showsIncomingDestinationPrompt: Bool
    public let incomingDestinationTitle: String?
    public let trailEntryPrompt: RideNavigationTrailEntryPrompt?
    public let arrivalPrompt: RideNavigationArrivalPrompt?
    public let forkGuidance: RideNavigationForkGuidance?
    public let routePersistence: RideNavigationRoutePersistenceState
    public let canSaveCompletedRoute: Bool
    public let completedRouteName: String?
    public let summaryTitle: String
    public let summaryDetail: String

    public init(
        screen: Screen = .home,
        activity: Activity = .preview,
        mapScene: NavigationMapScene = .init(),
        mapSources: [MapSourceDescriptor] = [.appleStandard, .appleHybrid],
        selectedMapStyleID: String = MapSourceDescriptor.appleStandard.id,
        allowsFocusMapStyle: Bool = false,
        isHeadingUp: Bool = true,
        speedText: String = "--",
        speedUnit: String = "km/h",
        modeText: String = "MODE --",
        batteryText: String = "--%",
        elapsedText: String = "00:00",
        distanceText: String = "-- km",
        guidance: RideNavigationGuidance? = nil,
        routeTitle: String? = nil,
        savedRoutes: [RideNavigationRouteRow] = [],
        searchQuery: String = "",
        searchResults: [RideNavigationSearchResult] = [],
        roadRouteOptions: [RideNavigationRoadRouteOption] = [],
        avoidsTolls: Bool = false,
        avoidsHighways: Bool = false,
        showsRoadRoutePreferences: Bool = false,
        isCalculatingRoadRoutes: Bool = false,
        isPreparingTrail: Bool = false,
        isRerouting: Bool = false,
        isSearching: Bool = false,
        errorText: String? = nil,
        isVoiceMuted: Bool = false,
        canReverseRoute: Bool = false,
        canMinimize: Bool = false,
        canFindTrailExit: Bool = false,
        canResumeGPX: Bool = false,
        isFindingTrailExit: Bool = false,
        trailExitPreview: RideNavigationTrailExitPreview? = nil,
        showsIncomingDestinationPrompt: Bool = false,
        incomingDestinationTitle: String? = nil,
        trailEntryPrompt: RideNavigationTrailEntryPrompt? = nil,
        arrivalPrompt: RideNavigationArrivalPrompt? = nil,
        forkGuidance: RideNavigationForkGuidance? = nil,
        routePersistence: RideNavigationRoutePersistenceState = .idle,
        canSaveCompletedRoute: Bool = false,
        completedRouteName: String? = nil,
        summaryTitle: String = "Ride complete",
        summaryDetail: String = ""
    ) {
        self.screen = screen
        self.activity = activity
        self.mapScene = mapScene
        self.mapSources = mapSources
        self.selectedMapStyleID = selectedMapStyleID
        self.allowsFocusMapStyle = allowsFocusMapStyle
        self.isHeadingUp = isHeadingUp
        self.speedText = speedText
        self.speedUnit = speedUnit
        self.modeText = modeText
        self.batteryText = batteryText
        self.elapsedText = elapsedText
        self.distanceText = distanceText
        self.guidance = guidance
        self.routeTitle = routeTitle
        self.savedRoutes = savedRoutes
        self.searchQuery = searchQuery
        self.searchResults = searchResults
        self.roadRouteOptions = roadRouteOptions
        self.avoidsTolls = avoidsTolls
        self.avoidsHighways = avoidsHighways
        self.showsRoadRoutePreferences = showsRoadRoutePreferences
        self.isCalculatingRoadRoutes = isCalculatingRoadRoutes
        self.isPreparingTrail = isPreparingTrail
        self.isRerouting = isRerouting
        self.isSearching = isSearching
        self.errorText = errorText
        self.isVoiceMuted = isVoiceMuted
        self.canReverseRoute = canReverseRoute
        self.canMinimize = canMinimize
        self.canFindTrailExit = canFindTrailExit
        self.canResumeGPX = canResumeGPX
        self.isFindingTrailExit = isFindingTrailExit
        self.trailExitPreview = trailExitPreview
        self.showsIncomingDestinationPrompt = showsIncomingDestinationPrompt
        self.incomingDestinationTitle = incomingDestinationTitle
        self.trailEntryPrompt = trailEntryPrompt
        self.arrivalPrompt = arrivalPrompt
        self.forkGuidance = forkGuidance
        self.routePersistence = routePersistence
        self.canSaveCompletedRoute = canSaveCompletedRoute
        self.completedRouteName = completedRouteName
        self.summaryTitle = summaryTitle
        self.summaryDetail = summaryDetail
    }
}
