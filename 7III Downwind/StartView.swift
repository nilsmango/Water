//
//  StartView.swift
//  7III Downwind
//
//  Created by Simon Lang on 30.12.23.
//

import SwiftUI
import UniformTypeIdentifiers

struct StartView: View {
    @ObservedObject var downwindManager: DownwindManager
    
    @State private var showRunPicker = false
    @State private var showStartRunSheet = false
    @State private var runType: RunType = .start
    
    @State private var showCaptureStatistics = false
        
    @State private var importedRuns: [ImportRun] = []
    @State private var isImporting: Bool = false
    @State private var isLoadingImportedRuns: Bool = false
    
    @State private var editTags = [String]()
    @State private var showTagsEditView = false
    @State private var editRunIndex: Int? = nil
    @State private var showSavedOverlay = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if downwindManager.lastVersionNewsClosed != downwindManager.currentAppVersion {
                        NewsSection(downwindManager: downwindManager)
                            .padding(.horizontal)
                    }
                    
                    if isLoadingImportedRuns {
                        ProgressView("Parsing Run(s)...")
                            .padding()
                    } else {
                        ForEach(importedRuns.sorted(by: { $0.startLocation?.timestamp ?? Date.distantPast < $1.startLocation?.timestamp ?? Date.distantPast })) { run in
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "calendar")
                                    Text(downwindManager.makeTimeIntervalDate(startDate: run.startLocation?.timestamp ?? run.locations.first?.timestamp ?? Date.now, endDate: run.locations.last?.timestamp ?? Date.now))
                                    
                                    Spacer()
                                }
                                .fontWeight(.bold)
                                
                                if let locationString = run.locationString {
                                    HStack {
                                        Image(systemName: "location.fill")
                                        
                                        Text(locationString)
                                        
                                        Spacer()
                                    }
                                    .fontWeight(.bold)
                                }
                                
                                
                                Text("Run Time: \(makePrettyTime(timeInMinutes: run.runTime))")
                                
                                Text("Total Distance: \(makePrettyDistance(meters: run.totalDistance, system: downwindManager.measurementSystem, statistics: true))")
                                
                                Text("Number of locations found: \(run.locations.count)")
                                
                                
                                let formattedTags = run.tags.joined(separator: " ")
                                Text("Tags: \(formattedTags.count > 0 ? formattedTags : "No Tags")")
                                
                                Button {
                                        editTags = run.tags
                                        editRunIndex = importedRuns.firstIndex(where: { $0.id == run.id })
                                        showTagsEditView = true
                                   
                                } label: {
                                    run.tags.isEmpty ? Label("Add Tags", systemImage: "") : Label("Edit Tags", systemImage: "")
                                }
                                .buttonStyle(.bordered)
                                
                                Menu {
                                    ForEach(WorkoutType.allCases.sorted(by: {
                                        (downwindManager.workoutUsageCount[$0] ?? 0) > (downwindManager.workoutUsageCount[$1] ?? 0)
                                    }), id: \.self) { type in
                                        if type != .not7IIIPaddleSport && type != .not7IIISurfingSport {
                                            Button(action: {
                                                let index = importedRuns.firstIndex(where: { $0.id == run.id })
                                                importedRuns[index!].workoutType = type
                                            }) {
                                                if run.workoutType == type {
                                                    Label(type.prettyString, systemImage: "checkmark")
                                                } else {
                                                    Text(type.prettyString)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Text(run.workoutType?.prettyString ?? "Select Activity")
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                                
                                HStack {
                                    Button {
                                        downwindManager.importRun(run: run)
                                        // when done remove from array
                                        importedRuns.removeAll(where: { $0.id == run.id })
                                        showSavedOverlay = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            showSavedOverlay = false
                                        }
                                        
                                    } label: {
                                        Label("Save Run", systemImage: "checkmark")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.accent)
                                    .disabled(run.workoutType == nil)
                                    
                                    Button {
                                        if let index = importedRuns.firstIndex(where: { $0.id == run.id }) {
                                            importedRuns.remove(at: index)
                                        }
                                    } label: {
                                        Label("Remove Run", systemImage: "xmark")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                                .padding(.top)
                                
                                
                                
                            }
                            .padding()
                            .background {
                                ListBackground()
                            }
                            .padding()
                        }
                    }
                    
                    Button {
                        isImporting = true
                    } label: {
                        Label(importedRuns.isEmpty ? "Import GPX Run(s)" :"Import more GPX Run(s)", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                    .disabled(isLoadingImportedRuns)
                    .padding(.top)
                    .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: [UTType(filenameExtension: "gpx")!],
                        allowsMultipleSelection: true
                    ) { result in
                        isLoadingImportedRuns = true
                        DispatchQueue.global(qos: .userInitiated).async {
                            let group = DispatchGroup()
                            var newRuns: [ImportRun] = []

                            switch result {
                            case .success(let urls):
                                for url in urls {
                                    group.enter()
                                    downwindManager.parseGPX(from: url) { run in
                                        if let run = run {
                                            newRuns.append(run)
                                        }
                                        group.leave()
                                    }
                                }

                                group.notify(queue: .main) {
                                    importedRuns.append(contentsOf: newRuns)
                                    isLoadingImportedRuns = false
                                }

                            case .failure(let error):
                                print("Error importing files: \(error)")
                                DispatchQueue.main.async {
                                    isLoadingImportedRuns = false
                                }
                            }
                        }
                    }
                    
                    StatisticsControlCenter(downwindManager: downwindManager)
                        .padding()
                    
                    if downwindManager.appOpened > 4 {
                        ReviewRequestView()
                            .padding(.horizontal)
                    }
                    
                    
                    if downwindManager.activeRun.active {
                        if downwindManager.user.onlyWatching == true {
                            RunMapView(downwindManager: downwindManager)
                        } else {
                            RunListView(downwindManager: downwindManager)
                        }
                    } else {
                        //                            Button(action: {
                        //                                showRunPicker = true
                        //                            }, label: {
                        //                                Label("Online Locations", systemImage: "wifi")
                        //                            })
                        //                            .buttonStyle(.bordered)
                        //                            .tint(.accentColor)
                        //                            .padding(.top, 8)
                    }
                    
                    if downwindManager.developerMode {
                        Toggle("Collect Raw GPS", isOn: $downwindManager.collectRawGPS)
                            .padding()
                        NavigationLink(destination: StatisticTestsView(downwindManager: downwindManager)) {
                            Label("Statistics Test", systemImage: "chart.xyaxis.line")
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                    
                    Spacer()
                    
                }
            }
        
            .navigationTitle(downwindManager.user.name.isEmpty ? "Aloha!" : "Aloha \(downwindManager.user.name)!")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: StatisticsView(downwindManager: downwindManager)) {
                        Label("Statistics", systemImage: "chart.xyaxis.line")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StartOptionsMenu(downwindManager: downwindManager)
                }
            }
            .overlay {
                OverlayAlertView(showAlert: $downwindManager.locationError, text: """
            Can't activate location services.
            Either your device is in Airplane mode or the device doesn’t have the required hardware.
            Please deactivate Airplane mode and try again.
            """)
            }
            .confirmationDialog("Pick Run Option", isPresented: $showRunPicker, actions: {
                Button("Start New Run") {
                    runType = .start
                    showStartRunSheet = true
                }
                Button("Join a Run") {
                    runType = .join
                    showStartRunSheet = true
                }
                Button("Watch a Run") {
                    runType = .watch
                    showStartRunSheet = true
                }
            })
            .overlay {
                VStack {
                    Spacer()
                    Text("Saved Run!")
                        .padding()
                        .background {
                            ListBackground()
                        }
                        .padding()
                        .opacity(showSavedOverlay ? 1.0 : 0.0)
                }
                
            }
            
            .sheet(isPresented: $showStartRunSheet, content: {
                NavigationStack {
                    StartRun(downwindManager: downwindManager, showSheet: $showStartRunSheet, runType: runType)
                        .navigationTitle(runType.buttonLabel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showStartRunSheet = false
                                } label: {
                                    Label("Close", systemImage: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.black, .gray)
                                }
                            }
                        }
                }
            })
            .sheet(isPresented: $downwindManager.showUpgradeSheet, content: {
                NavigationStack {
                    UpgradeView(downwindManager: downwindManager, showUpgradeView: $downwindManager.showUpgradeSheet)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    downwindManager.showUpgradeSheet = false
                                } label: {
                                    Label("Close", systemImage: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.black, .gray)
                                }
                            }
                        }
                }
            })
            
            .sheet(isPresented: $downwindManager.showingSummarySheet, content: {
                SummaryView(downwindManager: downwindManager)
            })
            
            .sheet(isPresented: $showTagsEditView, content: {
                NavigationStack {
                    List {
                        TagsEditView(tags: $editTags, downwindManager: downwindManager, type: .constant(.windsurf), locationString: .constant(""))
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(role: .destructive, action: {
                                showTagsEditView = false
                            }, label: {
                                Text("Cancel")
                            })
                            .tint(.red)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                if let editRunIndex = editRunIndex {
                                    importedRuns[editRunIndex].tags = editTags
                                }
                                showTagsEditView = false
                            }, label: {
                                Text("Save")
                            })
                            .disabled((editRunIndex != nil ? importedRuns[editRunIndex!].tags : []) == editTags)
                        }
                    }
                }
            })
            
            .background(.listBackground)
            
            //                .onAppear {
            //                    if downwindManager.user.id == nil {
            //                        showFirstTimeUserName = true
            //                    }
            //                }
        }
        
    }
}

#Preview {
    StartView(downwindManager: DownwindManager())
}
