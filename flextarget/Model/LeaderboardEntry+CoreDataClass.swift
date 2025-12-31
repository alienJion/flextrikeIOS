import Foundation
import CoreData

@objc(LeaderboardEntry)
public class LeaderboardEntry: NSManagedObject {

}

extension LeaderboardEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LeaderboardEntry> {
        return NSFetchRequest<LeaderboardEntry>(entityName: "LeaderboardEntry")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var baseFactor: Double
    @NSManaged public var adjustment: Double
    @NSManaged public var scoreFactor: Double

    @NSManaged public var athlete: Athlete?
    @NSManaged public var drillResult: DrillResult?
}

extension LeaderboardEntry: Identifiable {

}
