//
//  ViewModel.swift
//  PolarSaver
//
//  Created by Junho Choi on 14/03/2025.
//


import PolarBleSdk
import RxSwift
import Foundation
import CoreBluetooth


class PolarViewModel: ObservableObject, PolarBleApiObserver {
    let disposeBag = DisposeBag()
    
    private static let deviceId = "DD3C9721"
    
    private var api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main,
                                                                     features: [PolarBleSdkFeature.feature_hr,
                                                                                PolarBleSdkFeature.feature_polar_sdk_mode,
                                                                                PolarBleSdkFeature.feature_battery_info,
                                                                                PolarBleSdkFeature.feature_device_info,
                                                                                PolarBleSdkFeature.feature_polar_online_streaming,
                                                                                PolarBleSdkFeature.feature_polar_offline_recording,
                                                                                PolarBleSdkFeature.feature_polar_device_time_setup,
                                                                                PolarBleSdkFeature.feature_polar_h10_exercise_recording]
    )

    @Published var deviceConnectionState: DeviceConnectionState = DeviceConnectionState.disconnected(deviceId)

    //@Published var offlineRecordingFeature = OfflineRecordingFeature()
    @Published var offlineRecordingSettings: RecordingSettings? = nil
    //@Published var offlineRecordingEntries: OfflineRecordingEntries = OfflineRecordingEntries()
    
    @Published var polarExerciseEntries: PolarExerciseEntries = PolarExerciseEntries()
    //@Published var offlineRecordingData: OfflineRecordingData = OfflineRecordingData()
    @Published var generalMessage: Message? = nil
    @Published var exportProgress: Double = 0.0
    @Published var isExporting: Bool = false
    @Published var isBluetoothOn: Bool
    @Published var h10RecordingFeature: H10RecordingFeature = H10RecordingFeature()
    
    private var h10ExerciseEntry: PolarExerciseEntry?
    private var currentExerciseData: PolarExerciseData?
    
    init() {
        self.isBluetoothOn = api.isBlePowered
        
        api.polarFilter(true)
        api.observer = self
    }
    
    func deviceConnecting(_ identifier: PolarBleSdk.PolarDeviceInfo) {
        DispatchQueue.main.async {
            self.deviceConnectionState = .connecting(identifier.deviceId)
        }
    }
    
    func deviceConnected(_ identifier: PolarBleSdk.PolarDeviceInfo) {
        DispatchQueue.main.async {
            self.deviceConnectionState = .connected(identifier.deviceId)
        }
    }
    
    func deviceDisconnected(_ identifier: PolarBleSdk.PolarDeviceInfo, pairingError: Bool) {
        DispatchQueue.main.async {
            if case .connected(let deviceId) = self.deviceConnectionState, deviceId == identifier.deviceId {
                self.deviceConnectionState = .disconnected(deviceId)
                
                // Reset feature status on disconnect
                //self.offlineRecordingFeature = OfflineRecordingFeature()
                self.h10RecordingFeature = H10RecordingFeature()
            }
        }
    }
    
    func connectToDevice() {
        if case .disconnected(let deviceId) = deviceConnectionState {
            do {
                try api.connectToDevice(deviceId)
            } catch let err {
                NSLog("Failed to connect to \(deviceId). Reason \(err)")
            }
        }
    }
    
    func disconnectFromDevice() {
        if case .connected(let deviceId) = deviceConnectionState {
            do {
                try api.disconnectFromDevice(deviceId)
            } catch let err {
                NSLog("Failed to disconnect from \(deviceId). Reason \(err)")
            }
        }
    }
//    
//    func listOfflineRecordings() async {
//        if case .connected(let deviceId) = deviceConnectionState {
//            
//            Task { @MainActor in
//                self.offlineRecordingEntries.entries.removeAll()
//                self.offlineRecordingEntries.isFetching = true
//            }
//            NSLog("Start offline recording listing")
//            
//            api.listOfflineRecordings(deviceId)
//                .observe(on: MainScheduler.instance)
//                .debug("listOfflineRecordings")
//                .do(
//                    onDispose: {
//                        self.offlineRecordingEntries.isFetching = false
//                    })
//                .subscribe{ e in
//                    switch e {
//                    case .next(let entry):
//                        let identifiableEntry: IdentifiablePolarOfflineRecordingEntry = .init(entry: entry)
//                        self.offlineRecordingEntries.entries.append(identifiableEntry)
//                    case .error(let err):
//                        print(err.localizedDescription)
//                        NSLog("Offline recording listing error: \(err)")
//                    case .completed:
//                        NSLog("Offline recording listing completed")
//                    }
//                }.disposed(by: disposeBag)
//        }
//    }
//    
//    func getOfflineRecordingStatus() async {
//        if case .connected(let deviceId) = deviceConnectionState {
//            NSLog("getOfflineRecordingStatus")
//            api.getOfflineRecordingStatus(deviceId)
//                .observe(on: MainScheduler.instance)
//                .subscribe { e in
//                    switch e {
//                    case .success(let offlineRecStatus):
//                        NSLog("Enabled offline rec features \(offlineRecStatus)")
//                        self.offlineRecordingFeature.isRecording = offlineRecStatus
//                        
//                    case .failure(let err):
//                        NSLog("Failed to get status of offline recording \(err)")
//                    }
//                }.disposed(by: disposeBag)
//        }
//    }
//    
//    func removeOfflineRecording(offlineRecordingEntry: PolarOfflineRecordingEntry) async {
//        if case .connected(let deviceId) = deviceConnectionState {
//            do {
//                NSLog("start offline recording removal")
//                let _: Void = try await api.removeOfflineRecord(deviceId, entry: offlineRecordingEntry).value
//                NSLog("offline recording removal completed")
//                Task { @MainActor in
//                    self.offlineRecordingEntries.entries.removeAll{$0.entry == offlineRecordingEntry}
//                }
//            } catch let err {
//                NSLog("offline recording remove failed: \(err)")
//            }
//        }
//    }
//    
//    func getOfflineRecording(offlineRecordingEntry: PolarOfflineRecordingEntry) async {
//        if case .connected(let deviceId) = deviceConnectionState {
//            Task { @MainActor in
//                self.offlineRecordingData.loadState = OfflineRecordingDataLoadingState.inProgress
//            }
//            
//            do {
//                NSLog("start offline recording \(offlineRecordingEntry.path) fetch")
//                let readStartTime = Date()
//                let offlineRecording: PolarOfflineRecordingData = try await api.getOfflineRecord(deviceId, entry: offlineRecordingEntry, secret: nil).value
//                let elapsedTime = Date().timeIntervalSince(readStartTime)
//                
//                switch offlineRecording {
//                case .accOfflineRecordingData(let data, let startTime, let settings):
//                    NSLog("ACC data received")
//                    Task { @MainActor in
//                        self.offlineRecordingData.startTime = startTime
//                        self.offlineRecordingData.usedSettings = settings
//                        self.offlineRecordingData.data = dataHeaderString(.acc) + dataToString(data)
//                        self.offlineRecordingData.dataSize = offlineRecordingEntry.size
//                        self.offlineRecordingData.downLoadTime = elapsedTime
//                    }
//                case .gyroOfflineRecordingData(let data, startTime: let startTime, settings: let settings):
//                    NSLog("GYR data received")
//                    Task { @MainActor in
//                        self.offlineRecordingData.startTime = startTime
//                        self.offlineRecordingData.usedSettings = settings
//                        self.offlineRecordingData.data = dataHeaderString(.gyro) + dataToString(data)
//                        self.offlineRecordingData.dataSize = offlineRecordingEntry.size
//                        self.offlineRecordingData.downLoadTime = elapsedTime
//                    }
//                case .magOfflineRecordingData(let data, startTime: let startTime, settings: let settings):
//                    NSLog("MAG data received")
//                    Task { @MainActor in
//                        self.offlineRecordingData.startTime = startTime
//                        self.offlineRecordingData.usedSettings = settings
//                        self.offlineRecordingData.data = dataHeaderString(.magnetometer) + dataToString(data)
//                        self.offlineRecordingData.dataSize = offlineRecordingEntry.size
//                        self.offlineRecordingData.downLoadTime = elapsedTime
//                    }
//                case .ppgOfflineRecordingData(let data, startTime: let startTime, settings: let settings):
//                    NSLog("PPG data received")
//                    Task { @MainActor in
//                        self.offlineRecordingData.startTime = startTime
//                        self.offlineRecordingData.usedSettings = settings
//                        self.offlineRecordingData.data = dataHeaderString(.ppg) + dataToString(data)
//                        self.offlineRecordingData.dataSize = offlineRecordingEntry.size
//                        self.offlineRecordingData.downLoadTime = elapsedTime
//                    }
//                case .ppiOfflineRecordingData(let data, startTime: let startTime):
//                    NSLog("PPI data received")
//                    Task { @MainActor in
//                        self.offlineRecordingData.startTime = startTime
//                        self.offlineRecordingData.usedSettings = nil
//                        self.offlineRecordingData.data = dataHeaderString(.ppi) + dataToString(data)
//                        self.offlineRecordingData.dataSize = offlineRecordingEntry.size
//                        self.offlineRecordingData.downLoadTime = elapsedTime
//                    }
//                case .hrOfflineRecordingData(let data, startTime: let startTime):
//                    NSLog("HR data received")
//                    Task { @MainActor in
//                        self.offlineRecordingData.startTime = startTime
//                        self.offlineRecordingData.usedSettings = nil
//                        self.offlineRecordingData.data = dataHeaderString(.hr) + dataToString(data)
//                        self.offlineRecordingData.dataSize = offlineRecordingEntry.size
//                        self.offlineRecordingData.downLoadTime = elapsedTime
//                    }
//                case .temperatureOfflineRecordingData(let data, startTime: let startTime):
//                    NSLog("TEMP data received")
//                    Task { @MainActor in
//                        self.offlineRecordingData.startTime = startTime
//                        self.offlineRecordingData.usedSettings = nil
//                        self.offlineRecordingData.data = dataHeaderString(.temperature) + dataToString(data)
//                        self.offlineRecordingData.dataSize = offlineRecordingEntry.size
//                        self.offlineRecordingData.downLoadTime = elapsedTime
//                    }
//                case .skinTemperatureOfflineRecordingData(_, startTime: let startTime):
//                    NSLog("TEMP skin data received")
//                }
//                Task { @MainActor in
//                    self.offlineRecordingData.loadState = OfflineRecordingDataLoadingState.success
//                }
//            } catch let err {
//                NSLog("offline recording read failed: \(err)")
//                Task { @MainActor in
//                    self.offlineRecordingData.loadState = OfflineRecordingDataLoadingState.failed(error: "offline recording read failed: \(err)")
//                }
//            }
//        }
//    }
    
//    private func dataToString<T>(_ data: T) -> String {
//       var result = ""
//       switch data {
//       case let polarAccData as PolarAccData:
//           result += polarAccData.map{ "\($0.timeStamp) \($0.x) \($0.y) \($0.z)" }.joined(separator: "\n")
//       case let polarEcgData as PolarEcgData:
//           result +=  polarEcgData.map{ "\($0.timeStamp) \($0.voltage)" }.joined(separator: "\n")
//       case let polarGyroData as PolarGyroData:
//           result +=  polarGyroData.map{ "\($0.timeStamp) \($0.x) \($0.y) \($0.z)" }.joined(separator: "\n")
//       case let polarMagnetometerData as PolarMagnetometerData:
//           result +=  polarMagnetometerData.map{ "\($0.timeStamp) \($0.x) \($0.y) \($0.z)" }.joined(separator: "\n")
//       case let polarPpgData as PolarPpgData:
//           if polarPpgData.type == PpgDataType.ppg3_ambient1 {
//               result += polarPpgData.samples.map{ "\($0.timeStamp) \($0.channelSamples[0]) \($0.channelSamples[1]) \($0.channelSamples[2]) \($0.channelSamples[3])" }.joined(separator: "\n")
//           }
//       case let polarPpiData as PolarPpiData:
//           result += polarPpiData.samples.map{ "\($0.ppInMs) \($0.hr) \($0.ppErrorEstimate) \($0.blockerBit) \($0.skinContactSupported) \($0.skinContactStatus)" }.joined(separator: "\n")
//           
//       case let polarHrData as PolarHrData:
//           result += polarHrData.map{ "\($0.hr) \($0.contactStatusSupported) \($0.contactStatus) \($0.rrAvailable) \($0.rrsMs.map { String($0) }.joined(separator: " "))" }.joined(separator: "\n")
//       
//       case let polarTemperatureData as PolarTemperatureData:
//           result +=  polarTemperatureData.samples.map{ "\($0.timeStamp) \($0.temperature)" }.joined(separator: "\n")
//
//       case let polarPressureData as PolarPressureData:
//           result +=  polarPressureData.samples.map{ "\($0.timeStamp) \($0.pressure)" }.joined(separator: "\n")
//           
//       default:
//           result = "Data type not supported"
//       }
//       return result + "\n"
//    }
    
    private func somethingFailed(text: String) {
        self.generalMessage = Message(text: "Error: \(text)")
        NSLog("Error \(text)")
    }
    
//    private func dataHeaderString(_ type: PolarDeviceDataType) -> String {
//        var result = ""
//        switch type {
//        case .ecg:
//            result = "TIMESTAMP ECG(microV)\n"
//        case .acc:
//            result = "TIMESTAMP X(mg) Y(mg) Z(mg)\n"
//        case .ppg:
//            result =  "TIMESTAMP PPG0 PPG1 PPG2 AMBIENT\n"
//        case .ppi:
//            result = "PPI(ms) HR ERROR_ESTIMATE BLOCKER_BIT SKIN_CONTACT_SUPPORT SKIN_CONTACT_STATUS\n"
//        case .gyro:
//            result =  "TIMESTAMP X(deg/sec) Y(deg/sec) Z(deg/sec)\n"
//        case .magnetometer:
//            result =  "TIMESTAMP X(Gauss) Y(Gauss) Z(Gauss)\n"
//        case .hr:
//            result = "HR CONTACT_SUPPORTED CONTACT_STATUS RR_AVAILABLE RR(ms)\n"
//        case .temperature:
//            result = "TIMESTAMP TEMPERATURE(Celcius)\n"
//        case .pressure:
//            result = "TIMESTAMP PRESSURE(mBar)\n"
//        case .skinTemperature:
//            result = "SKIN TEMPERATURE(Celcius)\n"
//        }
//        return result
//    }
    
    public func exportRecording(format: ExportService.ExportFormat) {
        guard let exerciseData = self.currentExerciseData else {
            somethingFailed(text: "No exercise data available to export")
            return
        }
        
        guard let startTime = selectedExerciseEntry()?.date else {
            somethingFailed(text: "No start time set on extracted exercise data")
            return
        }
        
        do {
            let documentDirectoryUrl = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let fileUrl = try ExportService.exportRecording(data: exerciseData, format: format, startTime: startTime)
            let fileName = fileUrl.lastPathComponent
            let destinationUrl = documentDirectoryUrl.appendingPathComponent(fileName)
            if FileManager().fileExists(atPath: fileUrl.path) {
                try FileManager().copyItem(at: fileUrl, to: destinationUrl)
            }
        } catch let err {
            NSLog("Failed to export file from device. Reason \(err)")
        }
        
        
    }
    
    func selectedExerciseEntry() -> PolarExerciseEntry? {
        return h10ExerciseEntry
    }
    
    func h10ReadExercise() async {
        if case .connected(let deviceId) = deviceConnectionState {
            guard let selectedEntry = self.selectedExerciseEntry() else {
                somethingFailed(text: "No exercise selected, please select an exercise first")
                return
            }
            
            do {
                Task { @MainActor in
                    self.h10RecordingFeature.isFetchingRecording = true
                    self.polarExerciseEntries.isFetching = true
                }
                
                let data: PolarExerciseData = try await api.fetchExercise(deviceId, entry: selectedEntry).value
                NSLog("Exercise data count: \(data.samples.count) samples")
                
                Task { @MainActor in
                    self.currentExerciseData = data
                    self.h10RecordingFeature.isFetchingRecording = false
                }
                
            } catch let err {
                Task { @MainActor in
                    self.h10RecordingFeature.isFetchingRecording = false
                    self.polarExerciseEntries.isFetching = false
                    self.somethingFailed(text: "read H10 exercise failed: \(err)")
                }
            }
        }
    }
    
    func listH10Exercises() {
        if case .connected(let deviceId) = deviceConnectionState {
            // Reset the current entries and exercise data
            Task { @MainActor in
                self.polarExerciseEntries.entries.removeAll()
                self.polarExerciseEntries.isFetching = true
                self.h10ExerciseEntry = nil
                self.currentExerciseData = nil
            }

            api.fetchStoredExerciseList(deviceId)
                .observe(on: MainScheduler.instance)
                .subscribe{ e in
                    switch e {
                    case .completed:
                        NSLog("list exercises completed")
                        Task { @MainActor in
                            self.polarExerciseEntries.isFetching = false
                        }
                    case .error(let err):
                        NSLog("failed to list exercises: \(err)")
                        Task { @MainActor in
                            self.polarExerciseEntries.isFetching = false
                            self.somethingFailed(text: "Failed to list exercises: \(err)")
                        }
                    case .next(let polarExerciseEntry):
                        NSLog("entry: \(polarExerciseEntry.date.description) path: \(polarExerciseEntry.path) id: \(polarExerciseEntry.entryId)");
                        Task { @MainActor in
                            self.polarExerciseEntries.entries.append(IdentifiablePolarExerciseEntry(entry: polarExerciseEntry))
                            self.h10ExerciseEntry = polarExerciseEntry
                        }
                    }
                }.disposed(by: disposeBag)
        } else {
            somethingFailed(text: "Device not connected")
        }
    }
    
    func getH10RecordingStatus() {
       if case .connected(let deviceId) = deviceConnectionState, self.h10RecordingFeature.isSupported {
           api.requestRecordingStatus(deviceId)
               .observe(on: MainScheduler.instance)
               .subscribe{ e in
                   switch e {
                   case .failure(let err):
                       self.somethingFailed(text: "H10 recording status request failed: \(err)")
                   case .success(let pair):
                       var recordingStatus = "Recording on: \(pair.ongoing)."
                       if pair.ongoing {
                           recordingStatus.append(" Recording started with id: \(pair.entryId)")
                           Task { @MainActor in
                               self.h10RecordingFeature.isEnabled = true
                           }
                       } else {
                           Task { @MainActor in
                               self.h10RecordingFeature.isEnabled = false
                           }
                       }
                       NSLog(recordingStatus)
                   }
               }.disposed(by: disposeBag)
       }
   }
}

enum DeviceConnectionState {
    case disconnected(String)
    case connecting(String)
    case connected(String)
}

enum OfflineRecordingDataLoadingState {
    case inProgress
    case success
    case failed(error: String)
}

struct OfflineRecordingData: Identifiable {
    let id = UUID()
    var loadState: OfflineRecordingDataLoadingState = OfflineRecordingDataLoadingState.inProgress
    var startTime: Date = Date()
    var usedSettings: PolarSensorSetting? = nil
    var downLoadTime: TimeInterval? = nil
    var dataSize: UInt = 0
    var downloadSpeed: Double {
        if let time = downLoadTime, dataSize > 0 {
            return  Double(dataSize) / time
        } else {
            return 0.0
        }
    }
    var data:String = ""
}


struct OfflineRecordingEntries: Identifiable {
    let id = UUID()
    var isFetching: Bool = false
    var entries = [IdentifiablePolarOfflineRecordingEntry]()
}


struct OfflineRecordingFeature {
    var isSupported = false
    var availableOfflineDataTypes: [PolarDeviceDataType: Bool] = Dictionary(uniqueKeysWithValues: zip(PolarDeviceDataType.allCases, [false]))
    var isRecording: [PolarDeviceDataType: Bool] = Dictionary.init()
}

struct Message: Identifiable {
    let id = UUID()
    let text: String
}

struct RecordingSettings: Identifiable, Hashable {
    let id = UUID()
    let feature: PolarDeviceDataType
    var settings: [TypeSetting] = []
    var sortedSettings: [TypeSetting] { return settings.sorted{ $0.type.rawValue < $1.type.rawValue }}
}

struct TypeSetting: Identifiable, Hashable {
    let id = UUID()
    let type: PolarSensorSetting.SettingType
    var values: [Int] = []
    var sortedValues: [Int] { return values.sorted(by:<)}
}

struct IdentifiablePolarOfflineRecordingEntry: Identifiable {
    let id = UUID()
    let entry: PolarOfflineRecordingEntry
}

struct PolarExerciseEntries {
    var isFetching: Bool = false
    var entries = [IdentifiablePolarExerciseEntry]()
}

struct IdentifiablePolarExerciseEntry: Identifiable {
    let id = UUID()
    let entry: PolarExerciseEntry
}

//struct PolarExerciseData {
//    
//}


struct H10RecordingFeature {
    var isSupported = false
    var isEnabled = false
    var isFetchingRecording = false
}

