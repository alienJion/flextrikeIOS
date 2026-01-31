import SwiftUI
import CoreData

struct DrillSession {
    let sessionId: UUID
    let setup: DrillSetup
    let date: Date?
    let results: [DrillResult]
    
    var repeatCount: Int { results.count }
    var totalShots: Int {
        results.reduce(0) { $0 + (($1.shots as? Set<Shot>)?.count ?? 0) }
    }
}

struct HistoryTabView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State private var selectedDrillType: String? = nil
    @State private var selectedDrillName: String? = nil
    @State private var selectedDateRange: DateRange = .all
    @State private var expandedDrillSetups: Set<UUID> = []
    @State private var selectedResult: DrillResult? = nil
    @State private var showDetailView = false
    
    @FetchRequest(
        entity: DrillResult.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DrillResult.date, ascending: false)],
        animation: .default
    ) private var drillResults: FetchedResults<DrillResult>
    
    let persistenceController = PersistenceController.shared

    private static let filterSideInset: CGFloat = 16
    private static let filterChipSpacing: CGFloat = 12

    enum DateRange: Hashable {
        case all
        case week
        case month
        case custom(Date, Date)
        
        var startDate: Date? {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .all:
                return nil
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .custom(let start, _):
                return start
            }
        }
        
        var endDate: Date {
            switch self {
            case .custom(_, let end):
                return end
            default:
                return Date()
            }
        }
    }
    
    var groupedResults: [String: [DrillSession]] {
        var grouped: [String: [DrillSession]] = [:]
        
        let filtered = drillResults.filter { result in
            // Exclude results from competitions that have associated athletes
            // These are competition/match records, not personal drill records
            if result.competition != nil && result.athlete != nil {
                return false // Exclude competition results with athletes
            }
            
            // Filter by date range
            if let startDate = selectedDateRange.startDate, let resultDate = result.date {
                if resultDate < startDate || resultDate > selectedDateRange.endDate {
                    return false
                }
            }
            
            // Filter by drill type
            if let selectedType = selectedDrillType {
                if result.drillSetup?.mode != selectedType {
                    return false
                }
            }
            
            // Filter by drill name
            if let selectedName = selectedDrillName {
                if result.drillSetup?.name != selectedName {
                    return false
                }
            }
            
            return true
        }
        
        // Group by sessionId
        var sessionGroups: [UUID: [DrillResult]] = [:]
        for result in filtered {
            let sid = result.sessionId ?? UUID()
            if sessionGroups[sid] == nil {
                sessionGroups[sid] = []
            }
            sessionGroups[sid]?.append(result)
        }
        
        // Create sessions
        var sessions: [DrillSession] = sessionGroups.compactMap { (sid: UUID, results: [DrillResult]) -> DrillSession? in
            guard let firstResult = results.first, let setup = firstResult.drillSetup else { return nil }
            return DrillSession(sessionId: sid, setup: setup, date: firstResult.date, results: results)
        }
        
        // Sort sessions by date descending to ensure stable order
        sessions.sort { (a, b) -> Bool in
            let dateA = a.date ?? Date.distantPast
            let dateB = b.date ?? Date.distantPast
            if dateA != dateB {
                return dateA > dateB
            }
            return a.sessionId.uuidString > b.sessionId.uuidString
        }
        
        // Group by date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        for session in sessions {
            let dateKey = session.date.map { dateFormatter.string(from: $0) } ?? NSLocalizedString("unknown_date", comment: "Unknown date")
            
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            
            grouped[dateKey]?.append(session)
        }
        
        return grouped
    }
    
    var uniqueDrillTypes: [String] {
        let types = Set(drillResults.compactMap { $0.drillSetup?.mode })
        return Array(types).sorted()
    }
    
    var uniqueDrillNames: [String] {
        let names = Set(drillResults.compactMap { $0.drillSetup?.name })
        return Array(names).sorted()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 筛选区：三按钮固定间距、左右边距一致
                HStack(spacing: 0) {
                    Spacer(minLength: HistoryTabView.filterSideInset)
                    HStack(spacing: HistoryTabView.filterChipSpacing) {
                        Picker(selection: $selectedDrillType) {
                            Text(NSLocalizedString("all_modes", comment: "")).tag(nil as String?)
                            ForEach(uniqueDrillTypes, id: \.self) { type in
                                Text(type.uppercased()).tag(type as String?)
                            }
                        } label: {
                            filterChipLabel(icon: "line.3.horizontal.decrease.circle", title: selectedDrillType?.uppercased() ?? NSLocalizedString("all_modes", comment: ""))
                        }
                        .pickerStyle(.menu)

                        Picker(selection: $selectedDateRange) {
                            Text(NSLocalizedString("all_time", comment: "")).tag(DateRange.all)
                            Text(NSLocalizedString("past_week", comment: "")).tag(DateRange.week)
                            Text(NSLocalizedString("past_month", comment: "")).tag(DateRange.month)
                        } label: {
                            filterChipLabel(icon: "calendar", title: dateRangeLabel)
                        }
                        .pickerStyle(.menu)

                        Picker(selection: $selectedDrillName) {
                            Text(NSLocalizedString("all_drill_setup", comment: "")).tag(nil as String?)
                            ForEach(uniqueDrillNames, id: \.self) { name in
                                Text(name).tag(name as String?)
                            }
                        } label: {
                            filterChipLabel(icon: "target", title: selectedDrillName ?? NSLocalizedString("all_drill_setup", comment: ""))
                        }
                        .pickerStyle(.menu)
                    }
                    Spacer(minLength: HistoryTabView.filterSideInset)
                }
                .padding(.vertical, 12)
                .background(Color.black)

                // 列表
                if groupedResults.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(groupedResults.sorted(by: { $0.key > $1.key }), id: \.key) { dateKey, sessions in
                                sectionBlock(dateKey: dateKey, sessions: sessions)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 24)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                }
            }
            .navigationTitle(NSLocalizedString("history", comment: "History tab title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func filterChipLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.red)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(.red.opacity(0.8))
            Text(NSLocalizedString("no_results", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(NSLocalizedString("no_results_hint", comment: ""))
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func sectionBlock(dateKey: String, sessions: [DrillSession]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateKey)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.red)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 10) {
                ForEach(sessions, id: \.sessionId) { session in
                    sessionRow(session: session)
                }
            }
        }
    }

    private func sessionRow(session: DrillSession) -> some View {
        let isExpanded = expandedDrillSetups.contains(session.sessionId)
        return VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded {
                        expandedDrillSetups.remove(session.sessionId)
                    } else {
                        expandedDrillSetups.insert(session.sessionId)
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.setup.name ?? NSLocalizedString("untitled", comment: ""))
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(session.repeatCount) \(NSLocalizedString("repeats", comment: ""))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(Color.white.opacity(0.06))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(session.results, id: \.objectID) { result in
                        NavigationLink(destination: DrillSummaryView(drillSetup: session.setup, summaries: createSummaries(from: result) ?? [])
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)) {
                            if let summaries = createSummaries(from: result) {
                                DrillSummaryCard(drillSetup: session.setup, summaries: summaries)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 8)
            }
        }
    }
    
    private func createSummaries(from result: DrillResult) -> [DrillRepeatSummary]? {
        // Convert DrillResult to DrillRepeatSummary format for display
        guard let shots = result.shots as? Set<Shot> else { return nil }
        
        var shotDataArray: [ShotData] = []
        let decoder = JSONDecoder()
        
        for shot in shots {
            guard let data = shot.data else { continue }
            if let shotData = try? decoder.decode(ShotData.self, from: data.data(using: .utf8) ?? Data()) {
                shotDataArray.append(shotData)
            }
        }
        
        shotDataArray.sort { (a: ShotData, b: ShotData) in a.content.timeDiff < b.content.timeDiff }
        
        guard !shotDataArray.isEmpty else { return nil }
        
        // Calculate derived values
        let numShots = shotDataArray.count
        let firstShotTime = shotDataArray.first?.content.timeDiff ?? 0
        let fastestTime = shotDataArray.min(by: { (a: ShotData, b: ShotData) in a.content.timeDiff < b.content.timeDiff })?.content.timeDiff ?? 0
        
        var adjustedHitZones: [String: Int]? = nil
        if let adjustedStr = result.adjustedHitZones {
            let decoder = JSONDecoder()
            adjustedHitZones = try? decoder.decode([String: Int].self, from: adjustedStr.data(using: .utf8) ?? Data())
        }
        
        // Decode CQB data
        var cqbResults: [CQBShotResult]? = nil
        if let cqbResultsStr = result.cqbResults, 
           let data = cqbResultsStr.data(using: .utf8) {
            cqbResults = try? decoder.decode([CQBShotResult].self, from: data)
        }
        
        let cqbPassed: Bool? = result.cqbPassed?.boolValue
        
        let summary = DrillRepeatSummary(
            repeatIndex: 1,
            totalTime: result.totalTime?.doubleValue ?? 0,
            numShots: numShots,
            firstShot: firstShotTime,
            fastest: fastestTime,
            score: 0,
            shots: shotDataArray,
            drillResultId: result.id,
            adjustedHitZones: adjustedHitZones,
            cqbResults: cqbResults,
            cqbPassed: cqbPassed
        )
        
        return [summary]
    }
    
    private func createSummaries(for session: DrillSession) -> [DrillRepeatSummary]? {
        var summaries: [DrillRepeatSummary] = []
        for (index, result) in session.results.enumerated() {
            if let summary = createSummaries(from: result)?.first {
                let updatedSummary = DrillRepeatSummary(
                    repeatIndex: index + 1,
                    totalTime: summary.totalTime,
                    numShots: summary.numShots,
                    firstShot: summary.firstShot,
                    fastest: summary.fastest,
                    score: summary.score,
                    shots: summary.shots,
                    drillResultId: summary.drillResultId,
                    adjustedHitZones: summary.adjustedHitZones,
                    cqbResults: summary.cqbResults,
                    cqbPassed: summary.cqbPassed
                )
                summaries.append(updatedSummary)
            }
        }
        return summaries.isEmpty ? nil : summaries
    }
    
    private var dateRangeLabel: String {
        switch selectedDateRange {
        case .all:
            return NSLocalizedString("all_time", comment: "All time filter")
        case .week:
            return NSLocalizedString("past_week", comment: "Past week filter")
        case .month:
            return NSLocalizedString("past_month", comment: "Past month filter")
        case .custom:
            return NSLocalizedString("custom_date", comment: "Custom date filter")
        }
    }
}

// Helper card view for displaying summary in history
struct DrillSummaryCard: View {
    let drillSetup: DrillSetup
    let summaries: [DrillRepeatSummary]

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(drillSetup.name ?? NSLocalizedString("untitled", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(drillSetup.mode?.uppercased() ?? "N/A")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2fs", summaries.first?.totalTime ?? 0))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                Text("\(summaries.first?.shots.count ?? 0) shots")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationView {
        HistoryTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
