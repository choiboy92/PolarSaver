//
//  ContentView.swift
//  PolarSaver
//
//  Created by Junho Choi on 14/03/2025.
//

import SwiftUI
import PolarBleSdk

struct ContentView: View {
    @StateObject private var viewModel = PolarViewModel()
    @State private var showingExportOptions = false
    @State private var selectedExportFormat: ExportService.ExportFormat = .gpx
    @State private var selectedRecording: IdentifiablePolarExerciseEntry? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                connectionStatusView
                
                if case .connected = viewModel.deviceConnectionState {
                    recordingsListView
                } else {
                    instructionsView
                }
            }
            .navigationTitle("Polar H10")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if case .connected = viewModel.deviceConnectionState {
                        Button(action: {
                            viewModel.disconnectFromDevice()
                        }) {
                            Label("Disconnect", systemImage: "bluetooth.slash")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                exportOptionsView
            }
            .alert(item: $viewModel.generalMessage) { message in
                Alert(title: Text("Message"), message: Text(message.text), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private var connectionStatusView: some View {
        VStack {
            switch viewModel.deviceConnectionState {
            case .disconnected:
                Button(action: {
                    viewModel.connectToDevice()
                }) {
                    Label("Connect to Polar H10", systemImage: "bluetooth")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
            case .connecting:
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Connecting...")
                        .padding(.leading, 10)
                }
                .padding()
                
            case .connected(let deviceId):
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connected to \(deviceId)")
                    Spacer()
                    Button(action: {
                        Task {
                            viewModel.listH10Exercises()
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private var instructionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Connect to your Polar H10 to access exercise data")
                .font(.headline)
            
            Text("Make sure your Polar H10 is nearby and has saved training data")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var recordingsListView: some View {
        VStack {
            if viewModel.polarExerciseEntries.isFetching {
                ProgressView("Loading exercises...")
                    .padding()
            } else if viewModel.polarExerciseEntries.entries.isEmpty {
                VStack(spacing: 15) {
                    Text("No exercises found")
                        .font(.headline)
                    
                    Button(action: {
                        Task {
                            viewModel.listH10Exercises()
                        }
                    }) {
                        Label("Refresh List", systemImage: "arrow.clockwise")
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            } else {
                List {
                    ForEach(viewModel.polarExerciseEntries.entries) { identifiableEntry in
                        recordingRow(identifiableEntry)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    viewModel.listH10Exercises()
                }
            }
        }
        .onAppear {
            Task {
                viewModel.listH10Exercises()
            }
        }
        .sheet(item: $selectedRecording) { recording in
            recordingDetailView(recording)
        }
    }
    
    private func recordingRow(_ identifiableEntry: IdentifiablePolarExerciseEntry) -> some View {
        let entry = identifiableEntry.entry
        return HStack {
            VStack(alignment: .leading) {
                Text(getReadableRecordingName(from: entry.path))
                    .font(.headline)
                
                Text("Date: \(formatDate(entry.date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                selectedRecording = identifiableEntry
            }) {
                Image(systemName: "eye.fill")
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Menu {
                Button(action: {
                    selectedRecording = identifiableEntry
                    showingExportOptions = true
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive, action: {
                    Task {
                        await viewModel.h10ReadExercise()
                    }
                }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(.vertical, 4)
    }
    
    private func recordingDetailView(_ identifiableEntry: IdentifiablePolarExerciseEntry) -> some View {
        let exercise = identifiableEntry.entry
        return NavigationView {
            VStack {
                switch viewModel.h10RecordingFeature.isFetchingRecording {
                case true:
                    ProgressView("Loading exercise data...")
                
                case false:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            Group {
                                Text("Exercise Details")
                                    .font(.title)
                                    .padding(.bottom, 5)
                                
                                HStack {
                                    Text("Type:")
                                        .fontWeight(.bold)
                                    Text(getReadableRecordingName(from: exercise.path))
                                }
                                
                                HStack {
                                    Text("Date:")
                                        .fontWeight(.bold)
                                    Text(formatDate(exercise.date))
                                }
                                
                                HStack {
                                    Text("Entry ID:")
                                        .fontWeight(.bold)
                                    Text(exercise.entryId)
                                }
                            }
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.vertical)
                            
                            Text("Data Preview")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text("Exercise data will appear here after fetching")
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                            }
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            
                            Button(action: {
                                showingExportOptions = true
                            }) {
                                Label("Export Exercise", systemImage: "square.and.arrow.up")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        selectedRecording = nil
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.h10ReadExercise()
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                exportOptionsView
            }
        }
    }
    
    private var exportOptionsView: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $selectedExportFormat) {
                        ForEach(ExportService.ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("About Formats")) {
                    VStack(alignment: .leading, spacing: 10) {
                        formatInfoRow(title: "FIT", description: "Flexible and Interoperable Data Transfer. Used by Garmin devices.")
                        formatInfoRow(title: "TCX", description: "Training Center XML. Contains detailed workout data.")
                        formatInfoRow(title: "GPX", description: "GPS Exchange Format. Compatible with most fitness apps.")
                    }
                }
                
                Section {
                    if viewModel.isExporting {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Exporting...")
                                .padding(.leading, 10)
                        }
                    } else {
                        Button(action: {
                            exportSelectedRecording()
                        }) {
                            Label("Export as \(selectedExportFormat.rawValue)", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Export Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingExportOptions = false
                    }
                }
            }
        }
    }
    
    private func formatInfoRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func exportSelectedRecording() {
        guard let recording = selectedRecording else { return }
        
        Task {
            await viewModel.h10ReadExercise()
            await viewModel.exportRecording(format: selectedExportFormat)
            showingExportOptions = false
        }
    }
    
    // MARK: - Helper Functions
    
    private func getReadableRecordingName(from path: String) -> String {
        let components = path.split(separator: "/")
        guard let lastComponent = components.last else { return path }
        
        if lastComponent.lowercased().contains("hr") {
            return "Heart Rate Exercise"
        } else if lastComponent.lowercased().contains("exercise") {
            return "Fitness Exercise"
        } else {
            return String(lastComponent)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
