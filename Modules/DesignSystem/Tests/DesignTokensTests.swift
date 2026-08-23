import DesignSystem
import Testing

@Suite("FENR design tokens")
struct FENRDesignTokensTests {
    @Test("Uses a stable ascending spacing scale")
    func spacingScaleIsAscending() {
        #expect(DesignSpace.extraExtraSmall < DesignSpace.extraSmall)
        #expect(DesignSpace.extraSmall < DesignSpace.small)
        #expect(DesignSpace.small < DesignSpace.medium)
        #expect(DesignSpace.medium < DesignSpace.large)
    }

    @Test("Provides stable corner radii")
    func cornerRadiiAreStable() {
        #expect(DesignRadius.medium >= DesignRadius.small)
    }
}
