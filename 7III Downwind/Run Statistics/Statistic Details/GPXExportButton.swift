//
//  GPXExportButton.swift
//  7III Tracker
//
//  Created by Simon Lang on 05.02.2025.
//

import SwiftUI
import UniformTypeIdentifiers

extension WorkoutType {
    var gpxActivityType: String {
        switch self {
        case .foilSurf, .surf, .supSurf, .surfingSport, .not7IIISurfingSport:
            return "surfing"
        case .wingFoil:
            return "wingfoiling"
        case .parawing, .paraUpDown, .dWParawing:
            return "parawinging"
        case .windFoil, .windsurf:
            return "windsurfing"
        case .kiteFoil, .kite:
            return "kiteboarding"
        case .sup, .supFoil, .downwindSUP, .downwindSUPFoil, .paddleSport, .not7IIIPaddleSport:
            return "paddling"
        case .kayak:
            return "kayaking"
        case .canoe:
            return "canoeing"
        case .sailing:
            return "sailing"
        case .pumpFoil, .downwindProneFoil, .eFoil, .eAssist:
            return "hydrofoil"
        case .wakeFoil, .wakeSurf, .wakeThief:
            return "wakeboarding"
        case .windSkate, .wingSkate, .surfSkate, .pumpSkate, .pwSkate:
            return "skating"
        }
    }
}

struct GPXExportButton: View {
    let locationData: [LocationData]
    let activityName: String
    let workoutType: WorkoutType
    
    var body: some View {
        ShareLink(
            item: generateGPXFile(),
            preview: SharePreview("\(activityName).gpx", image: Image(systemName: "globe.europe.africa.fill"))
        ) {
            Label("GPX", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
        }
    }
    
    private func generateGPXFile() -> GPXFile {
        let gpxString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1"
            creator="7III Water"
            xmlns="http://www.topografix.com/GPX/1/1"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
            <metadata>
                <name>\(activityName)</name>
                <desc>\(workoutType.prettyString)</desc>
                <time>\(formatDate(locationData.first?.timestamp ?? Date()))</time>
            </metadata>
            <trk>
                <name>\(activityName)</name>
                <type>\(workoutType.gpxActivityType)</type>
                <trkseg>
                    \(locationData.map { point in """
                        <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                            <ele>0</ele>
                            <time>\(formatDate(point.timestamp))</time>
                            \(point.speed.map { "<speed>\($0)</speed>" } ?? "")
                        </trkpt>
                    """}.joined(separator: "\n"))
                </trkseg>
            </trk>
        </gpx>
        """
        return GPXFile(gpxString: gpxString, filename: "\(activityName).gpx")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

struct GPXFile: Transferable {
    let gpxString: String
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .gpx, exporting: { file in
            Data(file.gpxString.utf8)
        }, importing: { data in
            GPXFile(gpxString: String(decoding: data, as: UTF8.self), filename: "export.gpx")
        })
        .suggestedFileName { file in
            file.filename
        }
    }
}

extension UTType {
    static var gpx = UTType(exportedAs: "com.topografix.gpx")
}
