import SwiftUI
import CoreData

struct CompetitionDetailView: View {
    @ObservedObject var competition: Competition
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var bleManager: BLEManager
    
    @State private var showAthletePicker = false
    @State private var selectedAthlete: Athlete?
    @State private var navigateToTimerSession = false
    @State private var drillRepeatSummaries: [DrillRepeatSummary] = []
    @State private var navigateToDrillSummary = false
    @State private var showAckTimeoutAlert = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Competition Info Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(competition.name ?? "")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(competition.venue ?? "")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(competition.date ?? Date(), style: .date)
                            .foregroundColor(.red)
                    }
                    
                    if let drill = competition.drillSetup {
                        HStack {
                            Image(systemName: "target")
                            Text(drill.name ?? "")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                // Results List
                List {
                    Section(header: Text(NSLocalizedString("results", comment: "")).foregroundColor(.white)) {
                        if let results = competition.results?.allObjects as? [DrillResult], !results.isEmpty {
                            ForEach(results.sorted(by: { ($0.date ?? Date()) > ($1.date ?? Date()) })) { result in
                                CompetitionResultRow(result: result)
                            }
                            .listRowBackground(Color.white.opacity(0.1))
                        } else {
                            Text(NSLocalizedString("no_results_yet", comment: ""))
                                .foregroundColor(.gray)
                                .listRowBackground(Color.white.opacity(0.1))
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                
                // Start Button
                Button(action: {
                    showAthletePicker = true
                }) {
                    Text(NSLocalizedString("start_competition_drill", comment: ""))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(bleManager.isConnected ? Color.red : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!bleManager.isConnected)
                .padding()
            }
            
            // Navigation Links
            NavigationLink(isActive: $navigateToTimerSession) {
                if let drillSetup = competition.drillSetup {
                    TimerSessionView(
                        drillSetup: drillSetup,
                        bleManager: bleManager,
                        competition: competition,
                        athlete: selectedAthlete,
                        onDrillComplete: { summaries in
                            DispatchQueue.main.async {
                                drillRepeatSummaries = summaries
                                saveCompetitionResults(summaries)
                                navigateToDrillSummary = true
                                navigateToTimerSession = false
                            }
                        },
                        onDrillFailed: {
                            DispatchQueue.main.async {
                                showAckTimeoutAlert = true
                                navigateToTimerSession = false
                            }
                        }
                    )
                }
            } label: {
                EmptyView()
            }
            
            NavigationLink(isActive: $navigateToDrillSummary) {
                if let drillSetup = competition.drillSetup {
                    DrillSummaryView(drillSetup: drillSetup, summaries: drillRepeatSummaries)
                }
            } label: {
                EmptyView()
            }
        }
        .navigationTitle(NSLocalizedString("competition_details", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAthletePicker) {
            AthletePickerSheet { athlete in
                selectedAthlete = athlete
                navigateToTimerSession = true
            }
        }
        .alert(isPresented: $showAckTimeoutAlert) {
            Alert(title: Text(NSLocalizedString("error_title", comment: "")), message: Text(NSLocalizedString("ack_timeout_message", comment: "")), dismissButton: .default(Text(NSLocalizedString("ok", comment: ""))))
        }
    }
    
    private func saveCompetitionResults(_ summaries: [DrillRepeatSummary]) {
        guard let drillSetup = competition.drillSetup, let drillId = drillSetup.id else { return }
        
        let sessionId = UUID()
        for summary in summaries {
            let drillResult = DrillResult(context: viewContext)
            drillResult.id = UUID()
            drillResult.drillId = drillId
            drillResult.sessionId = sessionId
            drillResult.date = Date()
            drillResult.totalTime = summary.totalTime
            drillResult.drillSetup = drillSetup
            drillResult.competition = competition
            
            // Create LeaderboardEntry for the athlete
            if let athlete = selectedAthlete {
                let entry = LeaderboardEntry(context: viewContext)
                entry.id = UUID()
                entry.createdAt = Date()
                entry.athlete = athlete
                entry.drillResult = drillResult
                
                let factor: Double = summary.totalTime > 0 ? (Double(summary.score) / summary.totalTime) : 0
                entry.baseFactor = factor
                entry.adjustment = 0
                entry.scoreFactor = factor
            }
            
            var cumulativeTime: Double = 0
            for shotData in summary.shots {
                cumulativeTime += shotData.content.timeDiff
                let shot = Shot(context: viewContext)
                do {
                    let jsonData = try JSONEncoder().encode(shotData)
                    shot.data = String(data: jsonData, encoding: .utf8)
                } catch {
                    print("Failed to encode shot data: \(error)")
                    shot.data = nil
                }
                shot.timestamp = Int64(cumulativeTime * 1000)
                shot.drillResult = drillResult
            }
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save competition results: \(error)")
        }
    }
}

struct CompetitionResultRow: View {
    let result: DrillResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let athlete = (result.leaderboardEntries?.allObjects as? [LeaderboardEntry])?.first?.athlete {
                    Text(athlete.name ?? "")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Text(NSLocalizedString("unknown_athlete", comment: ""))
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                Text(result.date ?? Date(), style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(String(format: "%.2fs", result.totalTime))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .padding(.vertical, 5)
    }
}
