//
//  ExportService.swift
//  PolarSaver
//
//  Created by Junho Choi on 14/03/2025.
//

import Foundation
import PolarBleSdk

class ExportService {
    
    enum ExportFormat: String, CaseIterable {
        case fit = "FIT"
        case tcx = "TCX"
        case gpx = "GPX"
    }
    
    enum ExportError: Error {
        case unsupportedFormat
        case noData
        case processingError(String)
    }
    
    // Main export function
    static func exportRecording(data: PolarExerciseData, format: ExportFormat, startTime: Date) throws -> URL {
        // Create a temporary directory for the export
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "PolarH10_\(startTime.timeIntervalSince1970).\(format.rawValue.lowercased())"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Check if data contains samples
        guard !data.samples.isEmpty else {
            throw ExportError.noData
        }
        
        // Convert data to the requested format
        switch format {
        case .fit:
            try createFitFile(data: data, startTime: startTime, fileURL: fileURL)
        case .tcx:
            try createTCXFile(data: data, startTime: startTime, fileURL: fileURL)
        case .gpx:
            try createGPXFile(data: data, startTime: startTime, fileURL: fileURL)
        }
        
        return fileURL
    }
    
    // Create GPX file
    private static func createGPXFile(data: PolarExerciseData, startTime: Date, fileURL: URL) throws {
        let gpxData = try convertToGPX(data, startTime: startTime)
        try gpxData.write(to: fileURL)
    }
    
    // Create TCX file
    private static func createTCXFile(data: PolarExerciseData, startTime: Date, fileURL: URL) throws {
        let tcxData = try convertToTCX(data, startTime: startTime)
        try tcxData.write(to: fileURL)
    }
    
    // Convert to GPX format
    private static func convertToGPX(_ exerciseData: PolarExerciseData, startTime: Date) throws -> Data {
        // Create GPX format XML
        var gpxString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="PolarSaver App" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <time>\(ISO8601DateFormatter().string(from: startTime))</time>
          </metadata>
          <trk>
            <name>Polar H10 Exercise</name>
            <trkseg>
        """
        
        // Add track points - Calculate timestamps based on interval
        let interval = TimeInterval(exerciseData.interval)
        
        for (index, hrValue) in exerciseData.samples.enumerated() {
            let timestamp = startTime.addingTimeInterval(interval * Double(index))
            let timestampString = ISO8601DateFormatter().string(from: timestamp)
            
            gpxString += """
                <trkpt lat="0.0" lon="0.0">
                  <time>\(timestampString)</time>
                  <extensions>
                    <hr>\(hrValue)</hr>
                  </extensions>
                </trkpt>
            """
        }
        
        gpxString += """
            </trkseg>
          </trk>
        </gpx>
        """
        
        return Data(gpxString.utf8)
    }
    
    // Convert to TCX format
    private static func convertToTCX(_ exerciseData: PolarExerciseData, startTime: Date) throws -> Data {
        // Calculate total exercise time
        let totalTimeSeconds = Double(exerciseData.interval) * Double(exerciseData.samples.count)
        
        // Create TCX format XML
        var tcxString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Other">
              <Id>\(ISO8601DateFormatter().string(from: startTime))</Id>
              <Lap StartTime="\(ISO8601DateFormatter().string(from: startTime))">
                <TotalTimeSeconds>\(totalTimeSeconds)</TotalTimeSeconds>
                <DistanceMeters>0.0</DistanceMeters>
                <Calories>0</Calories>
                <Intensity>Active</Intensity>
                <TriggerMethod>Manual</TriggerMethod>
                <Track>
        """
        
        // Add track points - Calculate timestamps based on interval
        let interval = TimeInterval(exerciseData.interval)
        
        for (index, hrValue) in exerciseData.samples.enumerated() {
            let timestamp = startTime.addingTimeInterval(interval * Double(index))
            let timestampString = ISO8601DateFormatter().string(from: timestamp)
            
            tcxString += """
                <Trackpoint>
                  <Time>\(timestampString)</Time>
                  <HeartRateBpm>
                    <Value>\(hrValue)</Value>
                  </HeartRateBpm>
                </Trackpoint>
            """
        }
        
        tcxString += """
                </Track>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
        
        return Data(tcxString.utf8)
    }
    
    // Create FIT file
    private static func createFitFile(data: PolarExerciseData, startTime: Date, fileURL: URL) throws {
        // Check if we have heart rate data
        if data.samples.isEmpty {
            throw ExportError.noData
        }
        
        // Create heart rate data array with timestamps
        let hrData = parseHeartRateData(data: data, startTime: startTime)
        
        // Create a simple CSV as a placeholder for FIT file
        // Note: For a real FIT file, you will need to use a FIT SDK or library
        var fitContent = "timestamp,heart_rate\n"
        
        for (timestamp, hr) in hrData {
            fitContent += "\(timestamp.timeIntervalSince1970),\(hr)\n"
        }
        
        try fitContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // For a real FIT file implementation, you would use a FIT SDK
        // like the Garmin FIT SDK or a third-party library
    }
    
    // Helper function to parse heart rate data
    private static func parseHeartRateData(data: PolarExerciseData, startTime: Date) -> [(timestamp: Date, hr: UInt32)] {
        var hrData: [(timestamp: Date, hr: UInt32)] = []
        let interval = TimeInterval(data.interval)
        
        for (index, hrValue) in data.samples.enumerated() {
            let timestamp = startTime.addingTimeInterval(interval * Double(index))
            hrData.append((timestamp: timestamp, hr: hrValue))
        }
        
        return hrData
    }
}
    // Create TCX file
//    private static func createTcxFile(data: PolarExerciseData, fileURL: URL) throws {
//        // Parse the data and extract heart rate values
//        let hrData = parseHeartRateData(data: data)
//        
//        if hrData.isEmpty {
//            throw ExportError.noData
//        }
//        
//        // Create a TCX file with heart rate data
//        let tcxContent = generateTcxFileContent(hrData: hrData, startTime: data.startTime)
//        
//        try tcxContent.write(to: fileURL, atomically: true, encoding: .utf8)
//    }
//    
//    // Create GPX file
//    private static func createGpxFile(data: PolarExerciseData, fileURL: URL) throws {
//        // Parse the data and extract heart rate values
//        let hrData = parseHeartRateData(data: data)
//        
//        if hrData.isEmpty {
//            throw ExportError.noData
//        }
//        
//        // Create a GPX file with heart rate data
//        let gpxContent = generateGpxFileContent(hrData: hrData, startTime: data.startTime)
//        
//        try gpxContent.write(to: fileURL, atomically: true, encoding: .utf8)
//    }
    
    // Parse heart rate data from the recording
//    private static func parseHeartRateData(data: OfflineRecordingData) -> [(timestamp: Date, hr: Int)] {
//        var hrData: [(timestamp: Date, hr: Int)] = []
//        
//        // Split the data into lines
//        let lines = data.data.split(separator: "\n")
//        
//        // Skip the header line
//        let dataLines = lines.dropFirst()
//        
//        for line in dataLines {
//            let components = line.split(separator: " ")
//            guard components.count >= 1 else { continue }
//            
//            // For HR data, the first component is the heart rate value
//            if let hr = Int(components[0]) {
//                // Calculate the timestamp based on the line number and sampling rate
//                let index = hrData.count
//                let timestamp = data.startTime.addingTimeInterval(Double(index))
//                
//                hrData.append((timestamp: timestamp, hr: hr))
//            }
//        }
//        
//        return hrData
//    }
//    
//    // Generate FIT file content
//    private static func generateFitFileContent(hrData: [(timestamp: Date, hr: Int)], startTime: Date) -> String {
//        // This is a placeholder for a real FIT file generator
//        // Actual FIT files are binary and require specialized libraries
//        
//        // For now, we'll create a simple text-based representation
//        var content = "# FIT File Export (Placeholder)\n"
//        content += "# This is a placeholder for a real FIT file. In a real implementation, a binary FIT file would be generated.\n"
//        content += "# Start Time: \(startTime)\n"
//        content += "# Data Points: \(hrData.count)\n\n"
//        
//        content += "Timestamp,HeartRate\n"
//        
//        for (timestamp, hr) in hrData {
//            content += "\(timestamp.ISO8601Format()),\(hr)\n"
//        }
//        
//        return content
//    }
//    
//    // Generate TCX file content
//    private static func generateTcxFileContent(hrData: [(timestamp: Date, hr: Int)], startTime: Date) -> String {
//        let dateFormatter = ISO8601DateFormatter()
//        
//        var content = """
//        <?xml version="1.0" encoding="UTF-8"?>
//        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" 
//                               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
//                               xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd">
//          <Activities>
//            <Activity Sport="Other">
//              <Id>\(dateFormatter.string(from: startTime))</Id>
//              <Lap StartTime="\(dateFormatter.string(from: startTime))">
//                <TotalTimeSeconds>\(hrData.count)</TotalTimeSeconds>
//                <DistanceMeters>0</DistanceMeters>
//                <MaximumSpeed>0</MaximumSpeed>
//                <Calories>0</Calories>
//                <AverageHeartRateBpm>
//                  <Value>\(hrData.map { $0.hr }.reduce(0, +) / max(1, hrData.count))</Value>
//                </AverageHeartRateBpm>
//                <MaximumHeartRateBpm>
//                  <Value>\(hrData.map { $0.hr }.max() ?? 0)</Value>
//                </MaximumHeartRateBpm>
//                <Intensity>Active</Intensity>
//                <TriggerMethod>Manual</TriggerMethod>
//                <Track>
//        """
//        
//        for (timestamp, hr) in hrData {
//            content += """
//                  <Trackpoint>
//                    <Time>\(dateFormatter.string(from: timestamp))</Time>
//                    <HeartRateBpm>
//                      <Value>\(hr)</Value>
//                    </HeartRateBpm>
//                  </Trackpoint>
//            """
//        }
//        
//        content += """
//                </Track>
//              </Lap>
//            </Activity>
//          </Activities>
//        </TrainingCenterDatabase>
//        """
//        
//        return content
//    }
//    
//    // Generate GPX file content
//    private static func generateGpxFileContent(hrData: [(timestamp: Date, hr: Int)], startTime: Date) -> String {
//        let dateFormatter = ISO8601DateFormatter()
//        
//        var content = """
//        <?xml version="1.0" encoding="UTF-8"?>
//        <gpx version="1.1" 
//             creator="PolarSaver App" 
//             xmlns="http://www.topografix.com/GPX/1/1" 
//             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
//             xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" 
//             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
//          <metadata>
//            <time>\(dateFormatter.string(from: startTime))</time>
//          </metadata>
//          <trk>
//            <name>Polar H10 Heart Rate Recording</name>
//            <trkseg>
//        """
//        
//        for (timestamp, hr) in hrData {
//            content += """
//              <trkpt lat="0" lon="0">
//                <ele>0</ele>
//                <time>\(dateFormatter.string(from: timestamp))</time>
//                <extensions>
//                  <gpxtpx:TrackPointExtension>
//                    <gpxtpx:hr>\(hr)</gpxtpx:hr>
//                  </gpxtpx:TrackPointExtension>
//                </extensions>
//              </trkpt>
//            """
//        }
//        
//        content += """
//            </trkseg>
//          </trk>
//        </gpx>
//        """
//        
//        return content
//    }
//}
