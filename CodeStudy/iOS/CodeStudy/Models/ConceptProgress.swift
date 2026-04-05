import Foundation
import SwiftData

@Model
final class ConceptProgress {
    @Attribute(.unique) var conceptID: String
    var conceptTitle: String
    var category: String
    var studiedCount: Int
    var masteredCount: Int
    var lastStudiedAt: Date?
    var isMastered: Bool

    init(conceptID: String, conceptTitle: String, category: String) {
        self.conceptID = conceptID
        self.conceptTitle = conceptTitle
        self.category = category
        self.studiedCount = 0
        self.masteredCount = 0
        self.isMastered = false
    }
}
