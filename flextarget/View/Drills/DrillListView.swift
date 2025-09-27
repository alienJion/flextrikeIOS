//
//  DrillListView.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/9/27.
//


import SwiftUI

struct DrillListView: View {
    @State private var searchText: String = ""
    @State private var drills: [DrillSetup] = []
    @Environment(\.dismiss) private var dismiss
    // For showing alerts
    @State private var showDeleteAlert = false
    @State private var drillToDelete: DrillSetup?

    var filteredDrills: [DrillSetup] {
        if searchText.isEmpty {
            return drills
        } else {
            return drills.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func drillRow(for drill: DrillSetup, at index: Int) -> some View {
        ZStack {
            NavigationLink(destination: EditDrillView(drillSetup: drill)) {
                EmptyView()
            }
            .opacity(0)
            
            let itemView = DrillListItemView(drill: drill, index: index + 1)
                .listRowInsets(EdgeInsets())
            
            itemView
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    copyButton(for: drill)
                    deleteButton(for: drill)
                }
        }
        .listRowBackground(Color.clear)
        .background(Color.clear)
    }
    
    private func copyButton(for drill: DrillSetup) -> some View {
        Button {
            var newDrill = drill
            newDrill = DrillSetup(
                id: UUID(),
                name: drill.name + " Copy",
                description: drill.description,
                demoVideoURL: drill.demoVideoURL,
                thumbnailURL: drill.thumbnailURL,
                delay: drill.delay,
                targets: drill.targets
            )
            DrillSetupStorage.shared.addDrillSetup(newDrill)
            drills = DrillSetupStorage.shared.drillSetups
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .tint(Color.gray)
    }
    
    private func deleteButton(for drill: DrillSetup) -> some View {
        Button(role: .destructive) {
            drillToDelete = drill
            showDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                // Search Field (unchanged)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    Text("Search")
                        .foregroundColor(.gray)
                    TextField("", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(24)
                .padding([.top, .horizontal])

                // Drill List
                List {
                    ForEach(Array(filteredDrills.enumerated()), id: \.element.id) { (index, drill) in
                        drillRow(for: drill, at: index)
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                Spacer()
                // Add New Drill Button (unchanged)
                NavigationLink(destination: AddDrillView()) {
                    Text("Add New Drill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                        .padding([.horizontal, .bottom])
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Drill List")
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }
            .onAppear {
                drills = DrillSetupStorage.shared.drillSetups
            }
        }
        .alert("Delete Drill?", isPresented: $showDeleteAlert, presenting: drillToDelete) { drill in
            Button("Delete", role: .destructive) {
                DrillSetupStorage.shared.deleteDrillSetup(withId: drill.id)
                drills = DrillSetupStorage.shared.drillSetups
            }
            Button("Cancel", role: .cancel) {}
        } message: { drill in
            Text("Are you sure you want to delete \(drill.name)? This cannot be undone.")
        }
    }
}
    
    
struct DrillListItemView: View {
    let drill: DrillSetup
    let index: Int
    
    var totalSets: Int {
        drill.targets.count
    }
    
    var totalDuration: Int {
        Int(drill.targets.reduce(0) { $0 + $1.timeout })
    }
    
    var totalShots: Int {
        drill.targets.reduce(0) { $0 + $1.countedShots }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top 1/3: Row 1 with light gray background
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .foregroundColor(.red)
                    Text("#\(index)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(drill.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(height: geometry.size.height / 3)
                .padding(.horizontal)
                .background(.gray.opacity(0.2))
                // Bottom 2/3:
                HStack(alignment: .center) {
                    HStack(spacing: 0) {
                        Spacer()
                        VStack {
                            Text("\(totalSets)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Sets")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("|")
                            .foregroundColor(.gray)
                        Spacer()
                        VStack {
                            Text("\(totalDuration)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Duration")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("|")
                            .foregroundColor(.gray)
                        Spacer()
                        VStack {
                            Text("\(totalShots)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Shots")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.red)
                        .padding(.leading, 8)
                }
                .padding(8)
                .frame(height: geometry.size.height * 2 / 3)
                .background(.gray.opacity(0.6))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.vertical, 4)
        }
        .frame(height: 100) // Adjust height as needed
    }
}
