import WidgetKit
import SwiftUI

@main
struct NomadWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
        TimeZoneWidget()
        CurrencyWidget()
        TranslationWidget()
        PackingListWidget()
        PassportDaysWidget()
    }
}
