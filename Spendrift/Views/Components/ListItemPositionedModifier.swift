//
//  ListItemPositionedModifier.swift
//  Spendrift
//
//  Shared first / middle / last vertical padding for grouped list rows.
//

import SwiftUI

enum ListItemPosition {
    case first
    case middle
    case last
    case only

    static func from(index: Int, count: Int) -> Self {
        if count <= 1 { return .only }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }

    var topPadding: CGFloat {
        switch self {
        case .first, .only: 12
        case .middle, .last: 6
        }
    }

    var bottomPadding: CGFloat {
        switch self {
        case .last, .only: 12
        case .first, .middle: 6
        }
    }
}

struct ListItemPositionedModifier: ViewModifier {
    let position: ListItemPosition

    func body(content: Content) -> some View {
        content
            .padding(.top, position.topPadding)
            .padding(.bottom, position.bottomPadding)
            // Rows are HStacks with a Spacer, so without an explicit shape a
            // .plain Button only reacts on its icon and text, not the gap.
            .contentShape(Rectangle())
    }
}

extension View {
    func listItemPositioned(_ position: ListItemPosition) -> some View {
        modifier(ListItemPositionedModifier(position: position))
    }

    func listItemPositioned(index: Int, count: Int) -> some View {
        listItemPositioned(.from(index: index, count: count))
    }
}
