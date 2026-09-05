//
//  ScrollEdgeStyle.swift
//  Spendrift
//
//  Soft fade / blur where scrolling content meets pinned chrome, matching
//  the system navigation-bar treatment instead of a hard clip.
//

import SwiftUI

extension View {
    /// Soft, blurred scroll-edge fade. No-op before iOS 26, where the API does not exist.
    @ViewBuilder
    func softScrollEdge(for edges: Edge.Set = .top) -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: edges)
        } else {
            self
        }
    }

    /// Pins custom header chrome so the scroll view underlaps it and the
    /// system can fade / blur rows as they pass underneath.
    @ViewBuilder
    func scrollingHeaderBar<Header: View>(
        @ViewBuilder header: () -> Header
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .top, spacing: 0) {
                header()
            }
        } else {
            self.safeAreaInset(edge: .top, spacing: 0) {
                header()
                    .background(.bar)
            }
        }
    }
}
