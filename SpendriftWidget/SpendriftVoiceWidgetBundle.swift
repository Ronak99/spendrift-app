//
//  SpendriftWidgetBundle.swift
//  SpendriftWidget
//
//  Created by Cursor on 23/03/26.
//

import SwiftUI
import WidgetKit

@main
struct SpendriftWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoiceLiveActivityWidget()
        QuickExpenseSmallWidget()
        CaptureHubMediumWidget()
        RecentTransactionsLargeWidget()
    }
}
