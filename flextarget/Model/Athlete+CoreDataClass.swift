import Foundation
import CoreData

@objc(Athlete)
public class Athlete: NSManagedObject {

}

extension Athlete {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Athlete> {
        return NSFetchRequest<Athlete>(entityName: "Athlete")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var club: String?
    @NSManaged public var avatarData: Data?
    @NSManaged public var leaderboardEntries: NSSet?
}

extension Athlete: Identifiable {

}
