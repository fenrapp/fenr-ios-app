import BikeDemo
import SwiftUI

struct AppDemoControlsButton: View {
    let model: BikeDemoViewModel
    @State private var showsControls = false

    var body: some View {
        BikeDemoAccessButton { showsControls = true }
            .sheet(isPresented: $showsControls) {
                BikeDemoPanel(state: model.viewState, onSelect: model.select)
            }
    }
}
