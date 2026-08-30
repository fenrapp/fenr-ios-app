import DesignSystem
import Testing

@Suite("FENR design tokens")
struct FENRDesignTokensTests {
    @Test("Provides exact spacing values")
    func spacingValuesAreStable() {
        #expect(DesignSpace.extraExtraSmall == 4)
        #expect(DesignSpace.extraSmall == 8)
        #expect(DesignSpace.small == 12)
        #expect(DesignSpace.medium == 16)
        #expect(DesignSpace.large == 24)
        #expect(DesignSpace.extraLarge == 32)
    }

    @Test("Provides exact corner radius values")
    func cornerRadiusValuesAreStable() {
        #expect(DesignRadius.small == 8)
        #expect(DesignRadius.medium == 12)
    }
}
