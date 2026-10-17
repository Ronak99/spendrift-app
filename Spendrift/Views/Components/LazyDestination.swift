//
//  LazyDestination.swift
//  Spendrift
//
//  Defers building a NavigationLink destination until it is pushed.
//

import SwiftUI

/// `NavigationLink { Destination() }` builds the destination on every render of the
/// link's parent. Screens whose initializers allocate view models, or touch
/// persistence, must not run that often, so the link holds this wrapper instead
/// and the real view is built only when the push happens.
struct LazyDestination<Content: View>: View {
    private let build: () -> Content

    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }

    var body: some View {
        build()
    }
}
