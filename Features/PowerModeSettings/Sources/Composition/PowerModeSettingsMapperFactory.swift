import Foundation

public enum PowerModeSettingsMapperFactory {
    public static func make(locale: Locale) -> PowerModeSettingsViewStateMapper {
        .init(controls: .init(locale: locale), statusMapper: .init(), selection: .init())
    }
}
