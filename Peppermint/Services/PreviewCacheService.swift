//
//  PreviewCacheService.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 3 - User Story 1: Preview cache management for performance optimization
//

import CoreData
import Foundation

// MARK: - Preview Cache Service

/// Service for managing STL preview cache with SHA256-based invalidation
final class PreviewCacheService {

    // MARK: - Properties

    private let context: NSManagedObjectContext
    private let cacheLimit: Int64 = 100 * 1024 * 1024  // 100MB cache limit

    // MARK: - Initialization

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Cache Retrieval

    /// Retrieves cached STL data if valid for current organizer state
    ///
    /// **Cache hit conditions**:
    /// 1. PreviewCache entity exists for organizer
    /// 2. Cache key matches current organizer geometry (SHA256 hash)
    /// 3. `includesPillVisualization` flag matches request
    ///
    /// **Cache miss scenarios** (returns nil):
    /// - No cache entry exists
    /// - Organizer geometry changed (compartment edited/added/removed)
    /// - Pill visualization setting changed
    /// - Medication data changed (for pill previews)
    ///
    /// - Parameters:
    ///   - organizer: The organizer design to check cache for
    ///   - includePills: Whether pill visualization is requested
    ///
    /// - Returns: Cached STL data if valid, `nil` if cache miss
    func getCachedSTL(for organizer: OrganizerDesign, includePills: Bool) -> Data? {
        guard let cache = organizer.previewCache else {
            print("💾 Cache miss: No cache entry exists")
            return nil
        }

        // Validate cache using SHA256 key comparison
        if cache.isValid(for: organizer, includePills: includePills) {
            print("✅ Cache hit: \(cache.fileSizeFormatted), \(cache.triangleCountFormatted)")
            print("   \(cache.cacheAgeDescription)")
            return cache.stlData
        } else {
            print("💾 Cache miss: Organizer geometry changed")
            return nil
        }
    }

    // MARK: - Cache Storage

    /// Stores STL data in cache with hash-based invalidation
    ///
    /// **Cache key generation**:
    /// - SHA256 hash of compartment IDs, dimensions, positions, colors
    /// - Includes medication data if `includePills` is true
    /// - Ensures cache invalidation when any geometry changes
    ///
    /// **Cache eviction**:
    /// - If total cache size exceeds 100MB, evicts oldest entries first
    /// - Maintains 100MB limit per SC-007 (cache reduces server load)
    ///
    /// - Parameters:
    ///   - stlData: The binary STL data to cache
    ///   - organizer: The organizer this STL represents
    ///   - includePills: Whether this STL includes pill visualization
    ///   - triangleCount: Number of triangles in the STL mesh
    func cacheSTL(_ stlData: Data, for organizer: OrganizerDesign, includePills: Bool, triangleCount: Int) {
        // Check if cache limit exceeded before adding
        evictOldestCacheIfNeeded()

        // Delete existing cache if present
        if let existingCache = organizer.previewCache {
            context.delete(existingCache)
        }

        // Create new cache entry
        let cache = PreviewCache(context: context)
        cache.id = UUID()
        cache.cacheKey = PreviewCache.generateCacheKey(for: organizer, includePills: includePills)
        cache.stlData = stlData
        cache.generatedAt = Date()
        cache.includesPillVisualization = includePills
        cache.triangleCount = Int32(triangleCount)
        cache.fileSizeBytes = Int64(stlData.count)
        cache.organizer = organizer

        // Save context
        do {
            try context.save()
            print("💾 Cached STL: \(cache.fileSizeFormatted), \(cache.triangleCountFormatted)")
            print("   Cache key: \(cache.cacheKey!.prefix(16))...")
        } catch {
            print("❌ Failed to save cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Cache Eviction

    /// Evicts oldest cache entries if total size exceeds 100MB limit
    ///
    /// **Eviction strategy**:
    /// 1. Calculate total cache size across all PreviewCache entities
    /// 2. If size > 100MB, sort by generatedAt (oldest first)
    /// 3. Delete entries until total size < 100MB
    ///
    /// **Performance**: O(n log n) where n = number of cached previews
    private func evictOldestCacheIfNeeded() {
        // Fetch all cache entries
        let fetchRequest: NSFetchRequest<PreviewCache> = PreviewCache.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "generatedAt", ascending: true)]

        do {
            let allCaches = try context.fetch(fetchRequest)

            // Calculate total cache size
            let totalSize = allCaches.reduce(Int64(0)) { $0 + $1.fileSizeBytes }

            guard totalSize > cacheLimit else {
                return  // Within limit, no eviction needed
            }

            print("⚠️ Cache limit exceeded: \(formatBytes(totalSize)) / \(formatBytes(cacheLimit))")

            // Evict oldest entries until under limit
            var currentSize = totalSize
            var evictedCount = 0

            for cache in allCaches {
                if currentSize <= cacheLimit {
                    break
                }

                print("   Evicting: \(cache.cacheKey!.prefix(16))... (\(cache.fileSizeFormatted))")
                currentSize -= cache.fileSizeBytes
                context.delete(cache)
                evictedCount += 1
            }

            try context.save()
            print("✅ Evicted \(evictedCount) cache entries, new size: \(formatBytes(currentSize))")

        } catch {
            print("❌ Cache eviction failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    /// Formats byte count in human-readable format
    private func formatBytes(_ bytes: Int64) -> String {
        let megabytes = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", megabytes)
    }
}
