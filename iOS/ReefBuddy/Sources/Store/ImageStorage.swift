import Foundation
import UIKit

// MARK: - Image Storage

/// Manages persistence of livestock photos using the file system.
/// Stores images in the app's documents directory and provides references.
/// Thread-safe for concurrent access.
class ImageStorage {
    
    // MARK: - Properties
    
    /// Base directory for storing images
    private let imagesDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        // Get app's documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imagesDirectory = documentsPath.appendingPathComponent("LivestockImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Save image data and return the file path
    /// - Parameters:
    ///   - imageData: The image data to save
    ///   - id: Unique identifier for the image (typically livestock or log ID)
    /// - Returns: The file path where the image was saved, or nil if saving failed
    func saveImage(_ imageData: Data, for id: UUID) -> String? {
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            print("💾 Saved image for \(id.uuidString) to \(fileURL.path)")
            return fileURL.path
        } catch {
            print("⚠️ Failed to save image for \(id.uuidString): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Load image data from file path
    /// - Parameter filePath: The file path to load from
    /// - Returns: Image data if found, nil otherwise
    func loadImage(from filePath: String) -> Data? {
        guard FileManager.default.fileExists(atPath: filePath) else {
            return nil
        }
        
        return try? Data(contentsOf: URL(fileURLWithPath: filePath))
    }
    
    /// Load image data by ID
    /// - Parameter id: The unique identifier for the image
    /// - Returns: Image data if found, nil otherwise
    func loadImage(for id: UUID) -> Data? {
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return try? Data(contentsOf: fileURL)
    }
    
    /// Delete image by ID
    /// - Parameter id: The unique identifier for the image
    func deleteImage(for id: UUID) {
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Deleted image for \(id.uuidString)")
        } catch {
            print("⚠️ Failed to delete image for \(id.uuidString): \(error.localizedDescription)")
        }
    }
    
    /// Delete image by file path
    /// - Parameter filePath: The file path to delete
    func deleteImage(at filePath: String) {
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch {
            print("⚠️ Failed to delete image at \(filePath): \(error.localizedDescription)")
        }
    }
    
    /// Get file path for an image ID (without loading)
    /// - Parameter id: The unique identifier for the image
    /// - Returns: The file path if it exists, nil otherwise
    func imagePath(for id: UUID) -> String? {
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return fileURL.path
    }
    
    /// Check if image exists for ID
    /// - Parameter id: The unique identifier for the image
    /// - Returns: True if image exists, false otherwise
    func imageExists(for id: UUID) -> Bool {
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Get total size of all stored images
    /// - Returns: Total size in bytes
    func totalImageSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }
}
