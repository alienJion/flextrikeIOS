import SwiftUI
import CoreData

struct LeaderboardView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: LeaderboardEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \LeaderboardEntry.scoreFactor, ascending: false)],
        animation: .default
    )
    private var entries: FetchedResults<LeaderboardEntry>

    @State private var selectedSummaryContext: SelectedSummaryContext? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                ForEach(Array(entries.enumerated()), id: \.element.objectID) { index, entry in
                    row(rank: index + 1, entry: entry, isEven: index % 2 == 0)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openLinkedSummary(for: entry)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .background(Color.black)

            NavigationLink(
                isActive: Binding(
                    get: { selectedSummaryContext != nil },
                    set: { newValue in
                        if !newValue { selectedSummaryContext = nil }
                    }
                )
            ) {
                if let selectedSummaryContext {
                    DrillSummaryView(drillSetup: selectedSummaryContext.drillSetup, summaries: selectedSummaryContext.summaries)
                        .environment(\.managedObjectContext, viewContext)
                }
            } label: {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle(NSLocalizedString("leaderboard_title", comment: "Leaderboard title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }

    private struct SelectedSummaryContext {
        let drillSetup: DrillSetup
        let summaries: [DrillRepeatSummary]
    }

    private func openLinkedSummary(for entry: LeaderboardEntry) {
        guard let drillResult = entry.drillResult else { return }
        guard let drillSetup = drillResult.drillSetup else { return }

        selectedSummaryContext = SelectedSummaryContext(
            drillSetup: drillSetup,
            summaries: [makeRepeatSummary(from: drillResult)]
        )
    }

    private func makeRepeatSummary(from result: DrillResult) -> DrillRepeatSummary {
        let shots = result.decodedShots

        var adjustedHitZones: [String: Int]? = nil
        if let adjustedData = result.adjustedHitZones?.data(using: .utf8) {
            adjustedHitZones = try? JSONDecoder().decode([String: Int].self, from: adjustedData)
        }

        return DrillRepeatSummary(
            id: result.id ?? UUID(),
            repeatIndex: 1,
            totalTime: result.effectiveTotalTime,
            numShots: shots.count,
            firstShot: shots.first?.content.timeDiff ?? 0,
            fastest: result.fastestShot,
            score: Int(result.totalScore),
            shots: shots,
            drillResultId: result.id,
            adjustedHitZones: adjustedHitZones
        )
    }

    private func row(rank: Int, entry: LeaderboardEntry, isEven: Bool) -> some View {
        let background = isEven ? Color.gray.opacity(0.25) : Color.gray.opacity(0.15)

        let athleteName = entry.athlete?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (athleteName?.isEmpty == false) ? athleteName! : NSLocalizedString("untitled", comment: "Fallback name")

        return HStack(spacing: 16) {
            Text("\(rank)")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 44, alignment: .center)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 12)

            HStack(spacing: 12) {
                avatarPreview(data: entry.athlete?.avatarData)

                Text(displayName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 10)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 12)

            Text(String(format: "%.2f", entry.scoreFactor))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 108, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(background)
    }

    @ViewBuilder
    private func avatarPreview(data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundColor(.gray)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
    }
}

#Preview {
    NavigationView {
        LeaderboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .preferredColorScheme(.dark)
    }
}
