//
//  VoiceLiveActivityAttributes.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct VoiceLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var state: String
        var message: String
    }

    var title: String
}
#endif
