import SwiftUI
import CoreData

struct CompetitionTabView: View {
    @AppStorage("isCompetitionLoggedIn") private var isCompetitionLoggedIn = false
    @Environment(\.managedObjectContext) var managedObjectContext
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isCompetitionLoggedIn {
                competitionMenuView
                    .navigationTitle(NSLocalizedString("competition", comment: "Competition tab"))
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                CompetitionLoginView()
            }
        }
    }
    
    private var competitionMenuView: some View {
        VStack(spacing: 20) {
//            Spacer()
            
            // Competitions Link
            NavigationLink(destination: CompetitionListView()) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("competitions", comment: "Competitions menu item"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(NSLocalizedString("view_competitions", comment: "View competitions description"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Shooters/Athletes Link
            NavigationLink(destination: AthletesManagementView()) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("shooters", comment: "Shooters menu item"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(NSLocalizedString("manage_shooters", comment: "Manage shooters description"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Leaderboard Link
            NavigationLink(destination: LeaderboardView()) {
                HStack {
                    Image(systemName: "list.number")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("leaderboard", comment: "Leaderboard menu item"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(NSLocalizedString("view_leaderboard", comment: "View leaderboard description"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    NavigationView {
        CompetitionTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
