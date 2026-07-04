//
//  CookingTimerWidgetBundle.swift
//  CookingTimerWidget
//
//  Created by 杨括 on 2026/7/4.
//

import WidgetKit
import SwiftUI

@main
struct CookingTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        CookingTimerWidget()
        CookingTimerWidgetControl()
        CookingTimerWidgetLiveActivity()
    }
}
