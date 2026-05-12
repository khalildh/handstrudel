import WidgetKit
import SwiftUI

@main
struct HandStrudelLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            HandStrudelLiveActivity()
        }
    }
}
