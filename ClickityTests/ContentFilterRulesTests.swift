//
//  ContentFilterRulesTests.swift
//  ClickityTests
//
//  Created by Joshua Sattler on 30.08.26.
//

import Testing
import CoreGraphics
@testable import Clickity

/// Tests for the pure window classification rules behind the content filters.
@MainActor
struct ContentFilterRulesTests {

    // MARK: - Fixtures

    private static let ownBundleID = "com.rezaulhreza.Clickity"

    private func visibility(
        wallpaper: Bool = true,
        dock: Bool = true,
        clickity: Bool = true,
        desktopIcons: Bool = true
    ) -> ContentVisibility {
        ContentVisibility(
            showWallpaper: wallpaper,
            showDock: dock,
            showClickity: clickity,
            showDesktopIcons: desktopIcons,
            ownBundleID: Self.ownBundleID
        )
    }

    private let wallpaper = CapturableWindow(id: 1, bundleID: "com.apple.dock", title: "Wallpaper-1")
    private let dock = CapturableWindow(id: 2, bundleID: "com.apple.dock", title: "Dock")
    private let backstop = CapturableWindow(id: 3, bundleID: "com.apple.WindowManager", title: "Backstop Window")
    private let ownWindow = CapturableWindow(id: 4, bundleID: ContentFilterRulesTests.ownBundleID, title: "Clickity")
    private let otherApp = CapturableWindow(id: 5, bundleID: "com.apple.Safari", title: "Safari")
    private let desktopIcons = CapturableWindow(id: 6, bundleID: "com.apple.finder", title: "", layer: ContentFilterRules.desktopIconLevel)
    private let finderWindow = CapturableWindow(id: 7, bundleID: "com.apple.finder", title: "Downloads")

    private var allWindows: [CapturableWindow] {
        [wallpaper, dock, backstop, ownWindow, otherApp, desktopIcons, finderWindow]
    }

    private func excluded(_ visibility: ContentVisibility) -> Set<CGWindowID> {
        Set(ContentFilterRules.excludedWindowIDs(from: allWindows, visibility: visibility))
    }

    private func excepted(_ visibility: ContentVisibility) -> Set<CGWindowID> {
        Set(ContentFilterRules.dockExceptionWindowIDs(from: allWindows, visibility: visibility))
    }

    // MARK: - requiresRebuild

    @Test func requiresNoRebuildWhenEverythingIsShown() {
        #expect(ContentFilterRules.requiresRebuild(visibility: visibility()) == false)
    }

    @Test(arguments: [
        (false, true, true),
        (true, false, true),
        (true, true, false),
        (false, false, false)
    ])
    func requiresRebuildWhenAnythingIsHidden(wallpaper: Bool, dock: Bool, clickity: Bool) {
        let hidden = visibility(wallpaper: wallpaper, dock: dock, clickity: clickity)
        #expect(ContentFilterRules.requiresRebuild(visibility: hidden))
    }

    // MARK: - Display Capture

    @Test func displayExcludesNothingWhenEverythingIsShown() {
        #expect(excluded(visibility()).isEmpty)
    }

    @Test func displayExcludesWallpaperAndBackstopWhenWallpaperIsHidden() {
        #expect(excluded(visibility(wallpaper: false)) == [wallpaper.id, backstop.id])
    }

    @Test func displayExcludesDockOnlyWhenDockIsHidden() {
        #expect(excluded(visibility(dock: false)) == [dock.id])
    }

    @Test func displayExcludesOwnWindowsWhenClickityIsHidden() {
        #expect(excluded(visibility(clickity: false)) == [ownWindow.id])
    }

    @Test func displayExcludesWallpaperAndDockTogether() {
        #expect(excluded(visibility(wallpaper: false, dock: false)) == [wallpaper.id, dock.id, backstop.id])
    }

    @Test func displayExcludesWallpaperAndOwnWindows() {
        #expect(excluded(visibility(wallpaper: false, clickity: false)) == [wallpaper.id, backstop.id, ownWindow.id])
    }

    @Test func displayExcludesDockAndOwnWindows() {
        #expect(excluded(visibility(dock: false, clickity: false)) == [dock.id, ownWindow.id])
    }

    @Test func displayExcludesEverythingHidden() {
        let ids = excluded(visibility(wallpaper: false, dock: false, clickity: false))
        #expect(ids == [wallpaper.id, dock.id, backstop.id, ownWindow.id])
    }

    @Test func displayExcludesOnlyFindersIconWindowWhenDesktopIconsAreHidden() {
        let hidden = visibility(desktopIcons: false)
        #expect(ContentFilterRules.requiresRebuild(visibility: hidden))
        #expect(excluded(hidden) == [desktopIcons.id])
    }

    @Test func otherWindowsAtTheIconLevelAreKept() {
        let overlay = CapturableWindow(id: 30, bundleID: "com.apple.WindowManager", title: "", layer: ContentFilterRules.desktopIconLevel)
        #expect(ContentFilterRules.excludedWindowIDs(from: [overlay], visibility: visibility(desktopIcons: false)).isEmpty)
    }

    @Test func applicationIgnoresDesktopIconVisibility() {
        #expect(excepted(visibility(desktopIcons: false)).isEmpty)
    }

    @Test func displayNeverExcludesOtherApplications() {
        let ids = excluded(visibility(wallpaper: false, dock: false, clickity: false))
        #expect(ids.contains(otherApp.id) == false)
    }

    // MARK: - Backstop

    @Test func backstopIsExcludedRegardlessOfOwner() {
        let windows = [
            CapturableWindow(id: 10, bundleID: "com.apple.dock", title: "Backstop"),
            CapturableWindow(id: 11, bundleID: "com.apple.WindowServer", title: "Backstop"),
            CapturableWindow(id: 12, bundleID: "", title: "Some Backstop Layer")
        ]

        let ids = ContentFilterRules.excludedWindowIDs(from: windows, visibility: visibility(wallpaper: false))
        #expect(Set(ids) == [10, 11, 12])
    }

    @Test func backstopIsKeptWhenWallpaperIsShown() {
        let ids = ContentFilterRules.excludedWindowIDs(from: [backstop], visibility: visibility(dock: false))
        #expect(ids.isEmpty)
    }

    // MARK: - Wallpaper vs. Dock Split

    @Test func dockOwnedWindowsAreSplitByTitlePrefix() {
        let windows = [
            CapturableWindow(id: 20, bundleID: "com.apple.dock", title: "Wallpaper-2"),
            CapturableWindow(id: 21, bundleID: "com.apple.dock", title: "Dock")
        ]

        #expect(ContentFilterRules.excludedWindowIDs(from: windows, visibility: visibility(wallpaper: false)) == [20])
        #expect(ContentFilterRules.excludedWindowIDs(from: windows, visibility: visibility(dock: false)) == [21])
    }

    // MARK: - Application Capture

    @Test func applicationIncludesDockWhenAnySurfaceIsShown() {
        #expect(ContentFilterRules.includesDockApplication(visibility: visibility()))
        #expect(ContentFilterRules.includesDockApplication(visibility: visibility(wallpaper: false)))
        #expect(ContentFilterRules.includesDockApplication(visibility: visibility(dock: false)))
    }

    @Test func applicationOmitsDockWhenBothSurfacesAreHidden() {
        let onBlack = visibility(wallpaper: false, dock: false)
        #expect(ContentFilterRules.includesDockApplication(visibility: onBlack) == false)
        #expect(excepted(onBlack).isEmpty)
    }

    @Test func applicationExceptsNothingWhenEverythingIsShown() {
        #expect(excepted(visibility()).isEmpty)
    }

    @Test func applicationExceptsWallpaperAndBackstopWhenWallpaperIsHidden() {
        #expect(excepted(visibility(wallpaper: false)) == [wallpaper.id, backstop.id])
    }

    @Test func applicationExceptsDockOnlyWhenDockIsHidden() {
        #expect(excepted(visibility(dock: false)) == [dock.id])
    }

    /// `showClickity` is a display-capture concern: the picker excludes Clickity
    /// from application selections, so it never reaches the exception list.
    @Test func applicationIgnoresClickityVisibility() {
        #expect(excepted(visibility(clickity: false)).isEmpty)
        #expect(excepted(visibility(wallpaper: false, clickity: false)) == [wallpaper.id, backstop.id])
        #expect(excepted(visibility(dock: false, clickity: false)) == [dock.id])
    }

    @Test func applicationNeverExceptsTheCapturedApplication() {
        let ids = excepted(visibility(wallpaper: false))
        #expect(ids.contains(otherApp.id) == false)
    }
}
