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
    /// Header half of an expandable row; detail sits flush underneath.
    case expandedHeader
    /// Detail half of an expandable row; sits flush under its header.
    case expandedBody

    static func from(index: Int, count: Int) -> Self {
        if count <= 1 { return .only }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }

    var topPadding: CGFloat {
        switch self {
        case .first, .only: 12
        case .middle, .last, .expandedHeader: 6
        case .expandedBody: 0
        }
    }

    var bottomPadding: CGFloat {
        switch self {
        case .last, .only: 12
        case .first, .middle, .expandedBody: 6
        case .expandedHeader: 0
        }
    }
}

struct ListItemPositionedModifier: ViewModifier {
    let position: ListItemPosition

    /// At least the widest inset `.insetGrouped` puts between a row and its cell edge.
    private static let rowInsetReach: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(.top, position.topPadding)
            .padding(.bottom, position.bottomPadding)
            // Rows are HStacks with a Spacer, so without an explicit shape a
            // .plain Button only reacts on its icon and text, not the gap.
            // The shape also reaches past the frame into the row insets the List
            // adds around it, so the card's gutter opens the row too. Every caller
            // is a List row, whose cell bounds keep this from reaching a neighbour.
            .contentShape(Rectangle().inset(by: -Self.rowInsetReach))
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
