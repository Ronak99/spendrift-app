//
//  AppRouteTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct AppRouteTests {
    @Test
    func parsesCanonicalPaths() {
        #expect(AppRoute(path: "/feedback") == .feedback)
        #expect(AppRoute(path: "/explore") == .explore)
    }

    @Test
    func toleratesMissingSlashCaseAndQuery() {
        #expect(AppRoute(path: "Feedback") == .feedback)
        #expect(AppRoute(path: " /explore/?utm=1 ") == .explore)
        #expect(AppRoute(path: "/FEEDBACK/") == .feedback)
    }

    @Test
    func rejectsUnknownPaths() {
        #expect(AppRoute(path: "/settings") == nil)
        #expect(AppRoute(path: "") == nil)
        #expect(AppRoute(path: "/") == nil)
    }
}
