//
//  RunListView.swift
//  7III Downwind
//
//  Created by Simon Lang on 02.01.24.
//

import SwiftUI

struct RunListView: View {
    @AppStorage("runListSorting") private var runListSorting: RunListSorting = .distanceAscending
    
    @State private var runMembers = [Member(id: UUID(), name: "Fritz", latitude: 48.13, longitude: 55.2, speed: 23.3), Member(id: UUID(), name: "Franz", latitude: 48.1, longitude: 55.2, speed: 0.05), Member(id: UUID(), name: "Florian", latitude: 48.1206, longitude: 55.2018, speed: 0.45), Member(id: UUID(), name: "Zuschauer", onlyWatching: true), Member(id: UUID(), name: "Max", latitude: nil, longitude: nil, speed: nil), Member(id: UUID(), name: "Moritz", latitude: nil, longitude: nil, speed: nil), Member(id: UUID(), name: "Michael", latitude: 48.1, longitude: 55.1, speed: nil)]
    
    private var myself = Member(id: UUID(), name: "Nils Mango", latitude: 48.1206, longitude: 55.202)
    
    private var myTrueHeading: Double = 89.3
    
    private var distances: [Member: Double] {
        var distances = [Member: Double]()
        for member in runMembers {
            if let distance = calculateDirectDistance(from: myself, to: member) {
                distances[member] = distance
            }
        }
        return distances
    }
    
    
    var body: some View {
        VStack {
            List {
                ForEach(sortedMembers()) { member in
                    if !(member.onlyWatching ?? false) {
                        HStack {
                            Text(member.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if let distance = distances[member] {
                                BearingArrowView(degrees: calculateBearingToTarget(myTrueHeading: myTrueHeading, myLatitude: myself.latitude!, myLongitude: myself.longitude!, targetLatitude: member.latitude!, targetLongitude: member.longitude!))
    //                                .frame(width: 25, height: 25)
                                    .padding(.trailing, 5)
    //                                .frame(maxWidth: .infinity, alignment: .center)
                                
                                Text(makePrettyDistance(meters: distance))
                                    .fontWeight(.bold)
    //                                    .frame(maxWidth: .infinity, alignment: .center)
                                Group {
                                    if let speed = member.speed {
                                        Text("\(makePrettySpeed(speed: speed)) km/h")
                                    } else {
                                        Text("- km/h")
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                
                            } else {
                                Text("No Data")
                                Text("- km/h")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    
                }
                .onMove(perform: { indices, newOffset in
                    // TODO: move this function into the model (doesn't really make a difference though)
                    runMembers.move(fromOffsets: indices, toOffset: newOffset)
                    runListSorting = .custom
                })
            }
            
            HStack {
                Button(action: {
                    // show overlay asking: are you sure? there is no turning back. then exit run
                }, label: {
                    Label("Exit Run", systemImage: "door.left.hand.open")
                })
                .buttonStyle(.bordered)
                .padding()
                
                Menu {
                    Picker("Sorting", selection: $runListSorting) {
                        ForEach(RunListSorting.allCases) { sortCase in
                            Text(sortCase.rawValue)
                        }
                    }
                }
            label: {
                Label("Sort by", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.bordered)
            .padding()
            }
        }
    }
        
        
    func sortedMembers() -> [Member] {
        let stupidlyHighNumber = 10000000000.9
        let stupidlyLowNumber = -1.0
        switch runListSorting {
        case .name:
            return runMembers.sorted { $0.name < $1.name }
        case .distanceAscending:
            return runMembers.sorted { distances[$0] ?? stupidlyHighNumber < distances[$1] ?? stupidlyHighNumber}
        case .distanceDescending:
            return runMembers.sorted { distances[$0] ?? stupidlyLowNumber > distances[$1] ?? stupidlyLowNumber}
        case .custom:
            return runMembers
        }
    }
}

#Preview {
    RunListView()
}
