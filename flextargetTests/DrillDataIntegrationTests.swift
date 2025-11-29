import XCTest
import CoreData
//@testable import opencvtestminimal

final class DrillDataIntegrationTests: XCTestCase {
    // This test writes to the app's persistent store. Ensure the test target
    // is configured with the Host Application set to the app target so both
    // processes share the same sandbox and persistent store.

    func testPopulatePersistentStoreWithSampleDrill() throws {
        // Use the shared persistence controller used by the app
        let context = PersistenceController.shared.container.viewContext

        // Clean up any existing test data with a known marker name
        let markerName = "__UITEST_DRILL__"
        let fetchReq = NSFetchRequest<NSManagedObject>(entityName: "DrillSetup")
        fetchReq.predicate = NSPredicate(format: "name == %@", markerName)
        let existing = try context.fetch(fetchReq)
        for obj in existing { context.delete(obj) }

        // Create a DrillSetup using raw NSManagedObject to avoid cross-module subclass mismatch
        let drillSetup = NSEntityDescription.insertNewObject(forEntityName: "DrillSetup", into: context)
        drillSetup.setValue(UUID(), forKey: "id")
        drillSetup.setValue(markerName, forKey: "name")
        drillSetup.setValue("UI test drill", forKey: "desc")
        drillSetup.setValue(1.0, forKey: "delay")
        drillSetup.setValue(30.0, forKey: "drillDuration")
        // Set repeats to 1 (one repeat)
        drillSetup.setValue(1, forKey: "repeats")

        // Add three target configs and generate shots for each
        let types = ["hostage", "rotation", "paddle"]
        var generatedShots: [ShotData] = []
        var seq = 1
        for t in types {
            let targetName = "target_\(t)"
            let tc = NSEntityDescription.insertNewObject(forEntityName: "DrillTargetsConfig", into: context)
            tc.setValue(UUID(), forKey: "id")
            tc.setValue(Int32(seq), forKey: "seqNo")
            tc.setValue(targetName, forKey: "targetName")
            tc.setValue(t, forKey: "targetType")
            tc.setValue(10.0, forKey: "timeout")
            tc.setValue(Int32(5), forKey: "countedShots")
            tc.setValue(drillSetup, forKey: "drillSetup")
            seq += 1

            // Create several sample shots for this target (5 each)
            for i in 0..<5 {
                let jitterX = Double((i % 3) - 1) * 6.0
                let jitterY = Double((i % 2) - 1) * 8.0
                let centerX = 360.0 + Double(i * 7) + jitterX
                let centerY = 640.0 + Double(i * 9) + jitterY
                let timeDelta = 0.4 + Double(i) * 0.15
                let content = Content(command: "shot", hitArea: "C", hitPosition: Position(x: centerX, y: centerY), rotationAngle: 0, targetType: t, timeDiff: timeDelta, device: "device_\(t)")
                // Set ShotData.target to the targetName so UI can associate shots with each target
                let sd = ShotData(target: targetName, content: content, type: "shot", action: "hit", device: "device_\(t)", targetPos: nil)
                generatedShots.append(sd)
            }
        }

        // Create DrillResult and attach Shots
        let result = NSEntityDescription.insertNewObject(forEntityName: "DrillResult", into: context)
        result.setValue(drillSetup.value(forKey: "id") as? UUID, forKey: "drillId")
        result.setValue(Date(), forKey: "date")
        result.setValue(drillSetup, forKey: "drillSetup")
        result.setValue(generatedShots.map { $0.content.timeDiff }.reduce(0, +), forKey: "totalTime")

        for sd in generatedShots {
            let shotEntity = NSEntityDescription.insertNewObject(forEntityName: "Shot", into: context)
            let data = try JSONEncoder().encode(sd)
            shotEntity.setValue(String(data: data, encoding: .utf8), forKey: "data")
            shotEntity.setValue(Date(), forKey: "timestamp")
            shotEntity.setValue(result, forKey: "drillResult")
        }

        try context.save()

        // Verify saved
        let verifyReq = NSFetchRequest<NSManagedObject>(entityName: "DrillSetup")
        verifyReq.predicate = NSPredicate(format: "name == %@", markerName)
        let saved = try context.fetch(verifyReq)
        XCTAssertEqual(saved.count, 1, "Should have saved one marker drill setup")

        // The app can now be launched (manually) and should see this data in its UI.
    }
}
