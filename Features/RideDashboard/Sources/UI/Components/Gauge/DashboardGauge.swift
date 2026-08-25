import SwiftUI

struct DashboardGauge<Arc: View, Readout: View>: View {
    let arc: Arc
    let readout: Readout

    init(
        @ViewBuilder arc: () -> Arc,
        @ViewBuilder readout: () -> Readout
    ) {
        self.arc = arc()
        self.readout = readout()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            arc
            readout
                .padding(.bottom, readoutBottomInset)
        }
    }

    private var readoutBottomInset: CGFloat { 16 }
}
