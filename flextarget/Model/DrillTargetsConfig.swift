import Foundation

struct DrillTargetsConfigData: Identifiable, Codable, Equatable {
    let id: UUID
    var seqNo: Int
    var targetName: String
    var targetType: String
    var timeout: TimeInterval // seconds
    var countedShots: Int
    var action: String
    var duration: Double
    
    init(id: UUID = UUID(), seqNo: Int, targetName: String, targetType: String, timeout: TimeInterval, countedShots: Int, action: String = "", duration: Double = 0.0) {
        self.id = id
        self.seqNo = seqNo
        self.targetName = targetName
        self.targetType = targetType
        self.timeout = timeout
        self.countedShots = countedShots
        self.action = action
        self.duration = duration
    }
}