import Foundation
import CoreData

@objc(ExportHistory)
public class ExportHistory: NSManagedObject {
    // Computed properties
    var formattedFileSize: String {
        let bytes = Double(fileSize)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var wasSuccessful: Bool {
        return fileSize > 0
    }
}
