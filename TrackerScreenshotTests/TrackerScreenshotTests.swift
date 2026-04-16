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
    let output = URL(fileURLWithPath: "/Users/simxn/Documents/Geschäft/project7III/Apps/7III Water/Water App Store Metadata/Screenshots")
    let exporter = AppScreenshotExporter(option: .file(outputURL: output))
//    try exporter.export(Phone01AngleTool.self, captureDelay: 3)
//    try exporter.export(Phone02Dashboards.self)
    try exporter.export(Phone03Export.self, captureDelay: 6)
//    try exporter.export(Phone04Places.self)
//    try exporter.export(Phone05Tags.self)
//    try exporter.export(Phone06WatchSupport.self)
//    try exporter.export(Phone07WaterSports.self)
//    try exporter.export(Phone08StatisticsOverview.self)
//    try exporter.export(Phone09MakeEdits.self)
    try exporter.export(Phone10SimpleMap.self, captureDelay: 6)
    try exporter.export(Phone11StatsDetail.self, captureDelay: 6)
//    try exporter.export(Phone12GPXImport.self)
}
