//
//  TrackerScreenshotTests.swift
//  TrackerScreenshotTests
//
//  Created by Simon Lang on 07.04.2026.
//

import Project7IIIScreenshotTestTools
import Foundation
import Testing
@testable import _III_Water_Screenshots

@Test @MainActor
func exportScreenshots() throws {
    let output = ProcessInfo.processInfo.environment["WATER_SCREENSHOT_OUTPUT"]
        .map(URL.init(fileURLWithPath:))
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("7III-Water-Screenshots")
    let exporter = AppScreenshotExporter(option: .file(outputURL: output))
//    try exporter.export(Phone09AngleTool.self, captureDelay: 6)
//    try exporter.export(Phone12Dashboards.self)
//    try exporter.export(Phone07Export.self, captureDelay: 2)
//    try exporter.export(Phone08Places.self)
//    try exporter.export(Phone01WatchSupport.self)
//    try exporter.export(Phone02WaterSports.self)
//    try exporter.export(Phone04StatisticsOverview.self)
//    try exporter.export(Phone10RouteEdits.self)
//    try exporter.export(Phone06SimpleMap.self, captureDelay: 3)
//    try exporter.export(Phone05StatsDetail.self, captureDelay: 3)
//    try exporter.export(Phone03GPXImport.self)
//    try exporter.export(Phone11SpotsMap.self, captureDelay: 3)
//    try exporter.export(Phone05Tags.self)
    try exporter.export(Phone13WindAnalysis.self, captureDelay: 5)
    try exporter.export(WebsiteScreenshot01Overview.self, captureDelay: 3)
    try exporter.export(WebsiteScreenshot02Detail.self, captureDelay: 3)
}

@Test @MainActor
func exportWindRouteTestMaps() throws {
    let output = ProcessInfo.processInfo.environment["WATER_SCREENSHOT_TEST_OUTPUT"]
        .map(URL.init(fileURLWithPath:))
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("7III-Water-Test-Maps")
    let exporter = AppScreenshotExporter(option: .file(outputURL: output))
    try exporter.export(TestWindAnalysisSeptember18.self, captureDelay: 5)
    try exporter.export(TestWindAnalysisSeptember17.self, captureDelay: 5)
}
