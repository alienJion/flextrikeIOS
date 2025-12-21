//
//  DrillResult+CoreDataProperties.swift
//  FlexTarget
//
//  Created by Kai Yang on 2025/12/21.
//
//

public import Foundation
public import CoreData


public typealias DrillResultCoreDataPropertiesSet = NSSet

extension DrillResult {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DrillResult> {
        return NSFetchRequest<DrillResult>(entityName: "DrillResult")
    }

    @NSManaged public var date: Date?
    @NSManaged public var drillId: UUID?
    @NSManaged public var sessionId: UUID?
    @NSManaged public var totalTime: Double
    @NSManaged public var adjustedHitZones: String?
    @NSManaged public var id: UUID?
    @NSManaged public var drillSetup: DrillSetup?
    @NSManaged public var shots: NSSet?

}

// MARK: Generated accessors for shots
extension DrillResult {

    @objc(addShotsObject:)
    @NSManaged public func addToShots(_ value: Shot)

    @objc(removeShotsObject:)
    @NSManaged public func removeFromShots(_ value: Shot)

    @objc(addShots:)
    @NSManaged public func addToShots(_ values: NSSet)

    @objc(removeShots:)
    @NSManaged public func removeFromShots(_ values: NSSet)

}
