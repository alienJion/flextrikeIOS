import SwiftUI
import UIKit

struct RecentTrainingView: View {
    @State private var selectedPage: Int = 0
    private let summaries = DrillSummary.mock
    private var pageCount: Int { min(summaries.count, 3) }
    private let cardHeight: CGFloat = 288

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Drills")
                .font(.headline)
                .foregroundColor(.white)

            TabView(selection: $selectedPage) {
                let toShow = Array(summaries.prefix(pageCount))
                ForEach(Array(toShow.enumerated()), id: \ .1.id) { idx, summary in
                    // Card content with a proper rounded background
                    VStack(alignment: .leading, spacing: 0) {
                            //Title
                            HStack(spacing: 8) {
                                Image(systemName: "scope")
                                    .foregroundColor(.red)
                                Text(summary.drillName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                            // TargetTypeIcon (use first targetType -> asset name)
                            let rawName = summary.targetType.first ?? ""
                            let iconName = rawName
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .lowercased()
                                .replacingOccurrences(of: " ", with: "_")

                            HStack(spacing: 12) {
                                Spacer()
                                // Render up to two icons
                                ForEach(Array(summary.targetType.prefix(2).enumerated()), id: \ .offset) { _, raw in
                                    let name = raw
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                        .lowercased()
                                        .replacingOccurrences(of: " ", with: "_")
                                    Group {
                                        if let uiImage = UIImage(named: name) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                        } else {
                                            Image(systemName: "photo")
                                                .resizable()
                                        }
                                    }
                                    .scaledToFit()
                                    .frame(height: 120)
                                    .clipped()
                                    .cornerRadius(12)
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                            // Info Row (date moved to center, reduced numeric font size)
                            HStack {
                                VStack {
                                    Text(String(format: "%.1f", summary.hitFactor))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Hit Factor")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                VStack {
                                    // Date in center
                                    Text(Self.dateFormatter.string(from: summary.drillDate))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Date")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                VStack {
                                    Text(String(format: "%.2fs", summary.fastestShoot))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Fastest")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            // Page Indicator (re-using circles)
                            HStack(spacing: 8) {
                                ForEach(0..<pageCount, id: \ .self) { i in
                                    Circle()
                                        .fill(i == selectedPage ? Color.red : Color.gray.opacity(0.5))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.bottom, 12)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 0)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(20)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    // Card height (use same constant to avoid clipping)
                    .frame(height: cardHeight)
                    .padding(.horizontal, 4)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // ensure TabView is tall enough to show the full card including indicator
            .frame(height: cardHeight)
            .onAppear {
                // Clamp selected page to valid range in case mock count < 3
                if selectedPage >= pageCount {
                    selectedPage = max(0, pageCount - 1)
                }
            }
        }
    }

    // Date formatter used for displaying the drill date
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

struct RecentTrainingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RecentTrainingView()
                .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
