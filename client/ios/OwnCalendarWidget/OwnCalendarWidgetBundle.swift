import WidgetKit
import SwiftUI

@main
struct OwnCalendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        OwnCalendarWidget()
        OwnCalendarMonthlyWidget()
    }
}
