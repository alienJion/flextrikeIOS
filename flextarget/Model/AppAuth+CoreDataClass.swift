import Foundation
import CoreData

@objc(AppAuth)
public class AppAuth: NSManagedObject {

}

extension AppAuth {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppAuth> {
        return NSFetchRequest<AppAuth>(entityName: "AppAuth")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var token: String?
}

extension AppAuth: Identifiable {

}
