//
//  DataCacheManager.swift
//  SafeRouteAI
//
//  Advanced caching system for external API data with intelligent expiration
//  Supports memory, disk, and hybrid caching strategies
//

import Foundation
import CoreLocation
import Combine

// MARK: - Cache Configuration
struct CacheConfiguration {
    let memoryMaxItems: Int
    let memoryMaxAge: TimeInterval
    let diskMaxItems: Int
    let diskMaxAge: TimeInterval
    let compressionEnabled: Bool
    let encryptionEnabled: Bool
    
    static let `default` = CacheConfiguration(
        memoryMaxItems: 100,
        memoryMaxAge: 300, // 5 minutes
        diskMaxItems: 1000,
        diskMaxAge: 86400, // 24 hours
        compressionEnabled: true,
        encryptionEnabled: false
    )
    
    static let aggressive = CacheConfiguration(
        memoryMaxItems: 200,
        memoryMaxAge: 600, // 10 minutes
        diskMaxItems: 2000,
        diskMaxAge: 172800, // 48 hours
        compressionEnabled: true,
        encryptionEnabled: false
    )
    
    static let minimal = CacheConfiguration(
        memoryMaxItems: 50,
        memoryMaxAge: 180, // 3 minutes
        diskMaxItems: 500,
        diskMaxAge: 3600, // 1 hour
        compressionEnabled: false,
        encryptionEnabled: false
    )
}

// MARK: - Cache Entry
struct CacheEntry<T: Codable>: Codable {
    let key: String
    let data: T
    let timestamp: Date
    let expirationDate: Date
    let accessCount: Int
    let lastAccessed: Date
    let source: String
    let metadata: [String: String]
    
    var isExpired: Bool {
        return Date() > expirationDate
    }
    
    var age: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
    
    func withUpdatedAccess() -> CacheEntry<T> {
        return CacheEntry(
            key: key,
            data: data,
            timestamp: timestamp,
            expirationDate: expirationDate,
            accessCount: accessCount + 1,
            lastAccessed: Date(),
            source: source,
            metadata: metadata
        )
    }
}

// MARK: - Cache Statistics
struct CacheStatistics {
    let memoryItems: Int
    let diskItems: Int
    let memorySize: Int64
    let diskSize: Int64
    let hitRate: Double
    let missRate: Double
    let evictionCount: Int
    var lastCleanup: Date
    
    var totalItems: Int {
        return memoryItems + diskItems
    }
    
    var totalSize: Int64 {
        return memorySize + diskSize
    }
    
    var efficiency: Double {
        let totalRequests = hitRate + missRate
        return totalRequests > 0 ? hitRate / totalRequests : 0.0
    }
}

// MARK: - Cache Error
enum CacheError: Error {
    case dataNotFound
    case serializationFailed
    case deserializationFailed
    case storageError(String)
    case invalidConfiguration
    
    var localizedDescription: String {
        switch self {
        case .dataNotFound:
            return "Cached data not found"
        case .serializationFailed:
            return "Failed to serialize data for caching"
        case .deserializationFailed:
            return "Failed to deserialize cached data"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .invalidConfiguration:
            return "Invalid cache configuration"
        }
    }
}

// MARK: - Data Cache Manager
class DataCacheManager: ObservableObject {
    
    // MARK: - Configuration
    private let configuration: CacheConfiguration
    private let memoryCache = NSCache<NSString, NSData>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    
    // MARK: - Statistics
    @Published var statistics = CacheStatistics(
        memoryItems: 0,
        diskItems: 0,
        memorySize: 0,
        diskSize: 0,
        hitRate: 0.0,
        missRate: 0.0,
        evictionCount: 0,
        lastCleanup: Date()
    )
    
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0
    
    // MARK: - Initialization
    
    init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        
        // Setup disk cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.diskCacheURL = documentsPath.appendingPathComponent("SafeRouteAI_Cache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = configuration.memoryMaxItems
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Start periodic cleanup
        startPeriodicCleanup()
        
        // Load initial statistics
        updateStatistics()
    }
    
    // MARK: - Generic Cache Operations
    
    /// Store data in cache with intelligent key generation
    func store<T: Codable>(_ data: T, source: String, location: CLLocationCoordinate2D, radius: Double, customKey: String? = nil) throws {
        let key = customKey ?? generateCacheKey(source: source, location: location, radius: radius)
        let expirationDate = Date().addingTimeInterval(configuration.memoryMaxAge)
        
        let entry = CacheEntry(
            key: key,
            data: data,
            timestamp: Date(),
            expirationDate: expirationDate,
            accessCount: 1,
            lastAccessed: Date(),
            source: source,
            metadata: [
                "location": "\(location.latitude),\(location.longitude)",
                "radius": "\(radius)",
                "dataType": "\(T.self)"
            ]
        )
        
        // Store in memory cache
        let data = try JSONEncoder().encode(entry)
        memoryCache.setObject(data as NSData, forKey: key as NSString)
        
        // Store in disk cache for persistence
        try storeToDisk(entry, key: key)
        
        print("💾 Cached data for key: \(key)")
    }
    
    /// Retrieve data from cache with fallback strategy
    func retrieve<T: Codable>(type: T.Type, source: String, location: CLLocationCoordinate2D, radius: Double, customKey: String? = nil) throws -> T? {
        let key = customKey ?? generateCacheKey(source: source, location: location, radius: radius)
        
        // Try memory cache first
        if let nsData = memoryCache.object(forKey: key as NSString) {
            let data = nsData as Data
            let entry = try JSONDecoder().decode(CacheEntry<T>.self, from: data)
            
            if !entry.isExpired {
                // Update access statistics
                let updatedEntry = entry.withUpdatedAccess()
                let updatedData = try JSONEncoder().encode(updatedEntry)
                memoryCache.setObject(updatedData as NSData, forKey: key as NSString)
                
                hitCount += 1
                print("🎯 Cache hit (memory) for key: \(key)")
                return entry.data
            } else {
                // Remove expired entry
                memoryCache.removeObject(forKey: key as NSString)
                try removeFromDisk(key: key)
            }
        }
        
        // Try disk cache
        if let entry = try retrieveFromDisk(type: T.self, key: key) {
            if !entry.isExpired {
                // Promote to memory cache
                let data = try JSONEncoder().encode(entry)
                memoryCache.setObject(data as NSData, forKey: key as NSString)
                
                hitCount += 1
                print("🎯 Cache hit (disk) for key: \(key)")
                return entry.data
            } else {
                // Remove expired entry
                try removeFromDisk(key: key)
            }
        }
        
        missCount += 1
        print("❌ Cache miss for key: \(key)")
        return nil
    }
    
    /// Remove specific entry from cache
    func remove(source: String, location: CLLocationCoordinate2D, radius: Double, customKey: String? = nil) throws {
        let key = customKey ?? generateCacheKey(source: source, location: location, radius: radius)
        
        memoryCache.removeObject(forKey: key as NSString)
        try removeFromDisk(key: key)
        
        print("🗑️ Removed cache entry for key: \(key)")
    }
    
    /// Clear all cache data
    func clearAll() throws {
        memoryCache.removeAllObjects()
        
        let cacheFiles = try fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil)
        for file in cacheFiles {
            try fileManager.removeItem(at: file)
        }
        
        hitCount = 0
        missCount = 0
        evictionCount = 0
        
        print("🧹 Cleared all cache data")
        updateStatistics()
    }
    
    // MARK: - Intelligent Cache Operations
    
    /// Get nearby cached data within a certain radius
    func getNearbyData<T: Codable>(type: T.Type, location: CLLocationCoordinate2D, searchRadius: Double, maxResults: Int = 10) throws -> [(T, CacheEntry<T>)] {
        var results: [(T, CacheEntry<T>)] = []
        
        // Get all disk cache keys
        let cacheFiles = try fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil)
        
        for file in cacheFiles.prefix(maxResults) {
            let key = file.deletingPathExtension().lastPathComponent
            
            if let entry = try retrieveFromDisk(type: T.self, key: key) {
                // Check if location metadata exists and is within search radius
                if let locationString = entry.metadata["location"],
                   let radiusString = entry.metadata["radius"],
                   let cachedLocation = parseLocation(from: locationString),
                   let cachedRadius = Double(radiusString) {
                    
                    let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                        .distance(from: CLLocation(latitude: cachedLocation.latitude, longitude: cachedLocation.longitude))
                    
                    if distance <= searchRadius + cachedRadius {
                        results.append((entry.data, entry))
                    }
                }
            }
        }
        
        // Sort by distance and recency
        results.sort { result1, result2 in
            let location1 = parseLocation(from: result1.1.metadata["location"] ?? "") ?? location
            let location2 = parseLocation(from: result2.1.metadata["location"] ?? "") ?? location
            
            let distance1 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: location1.latitude, longitude: location1.longitude))
            let distance2 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: location2.latitude, longitude: location2.longitude))
            
            if abs(distance1 - distance2) < 10.0 { // Within 10m, sort by recency
                return result1.1.timestamp > result2.1.timestamp
            }
            
            return distance1 < distance2
        }
        
        return results
    }
    
    /// Preload cache data for a route
    func preloadRouteData(_ route: [CLLocationCoordinate2D], sources: [String], radius: Double = 200.0) async {
        print("🚀 Preloading cache data for route with \(route.count) waypoints")
        
        for source in sources {
            for waypoint in route {
                let key = generateCacheKey(source: source, location: waypoint, radius: radius)
                
                // Check if data is already cached
                if (try? retrieve(type: SafetyData.self, source: source, location: waypoint, radius: radius)) != nil {
                    continue
                }
                
                // Preload based on source type
                switch source {
                case "Weather Data":
                    // Preload weather data
                    _ = try? await preloadWeatherData(for: waypoint)
                case "Crime Data":
                    // Preload crime data
                    _ = try? await preloadCrimeData(for: waypoint, radius: radius)
                case "City Services (311)":
                    // Preload city service data
                    _ = try? await preloadCityServiceData(for: waypoint, radius: radius)
                case "Traffic Data":
                    // Preload traffic data
                    _ = try? await preloadTrafficData(for: waypoint, radius: radius)
                default:
                    break
                }
            }
        }
        
        print("✅ Route cache preloading complete")
    }
    
    // MARK: - Cache Maintenance
    
    private func startPeriodicCleanup() {
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    try? await self?.performCleanup()
                }
            }
            .store(in: &cancellables)
    }
    
    private func performCleanup() async throws {
        let startTime = Date()
        var removedCount = 0
        
        // Clean expired memory cache entries
        // Note: NSCache handles this automatically, but we can force cleanup if needed
        
        // Clean expired disk cache entries
        let cacheFiles = try fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey])
        
        for file in cacheFiles {
            let key = file.deletingPathExtension().lastPathComponent
            let attributes = try fileManager.attributesOfItem(atPath: file.path)
            
            if let modificationDate = attributes[.modificationDate] as? Date {
                let age = Date().timeIntervalSince(modificationDate)
                
                if age > configuration.diskMaxAge {
                    try fileManager.removeItem(at: file)
                    removedCount += 1
                }
            }
        }
        
        evictionCount += removedCount
        statistics.lastCleanup = Date()
        
        let duration = Date().timeIntervalSince(startTime)
        print("🧹 Cache cleanup completed in \(String(format: "%.2f", duration))s, removed \(removedCount) expired entries")
        
        updateStatistics()
    }
    
    private func updateStatistics() {
        // Update memory cache statistics
        let memoryItems = memoryCache.countLimit
        
        // Update disk cache statistics
        let diskItems: Int
        let diskSize: Int64
        
        do {
            let cacheFiles = try fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey])
            diskItems = cacheFiles.count
            diskSize = cacheFiles.reduce(0) { total, file in
                let attributes = try? fileManager.attributesOfItem(atPath: file.path)
                return total + (attributes?[.size] as? Int64 ?? 0)
            }
        } catch {
            diskItems = 0
            diskSize = 0
        }
        
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
        let missRate = totalRequests > 0 ? Double(missCount) / Double(totalRequests) : 0.0
        
        statistics = CacheStatistics(
            memoryItems: memoryItems,
            diskItems: diskItems,
            memorySize: Int64(memoryCache.totalCostLimit),
            diskSize: diskSize,
            hitRate: hitRate,
            missRate: missRate,
            evictionCount: evictionCount,
            lastCleanup: statistics.lastCleanup
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateCacheKey(source: String, location: CLLocationCoordinate2D, radius: Double) -> String {
        let roundedLat = round(location.latitude * 1000) / 1000
        let roundedLon = round(location.longitude * 1000) / 1000
        let roundedRadius = round(radius / 100) * 100
        return "\(source)_\(roundedLat)_\(roundedLon)_\(roundedRadius)"
    }
    
    private func parseLocation(from string: String) -> CLLocationCoordinate2D? {
        let components = string.components(separatedBy: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // MARK: - Disk Cache Operations
    
    private func storeToDisk<T: Codable>(_ entry: CacheEntry<T>, key: String) throws {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).cache")
        
        let data = try JSONEncoder().encode(entry)
        
        if configuration.compressionEnabled {
            let compressedData = try (data as NSData).compressed(using: .lzfse) as Data
            try compressedData.write(to: fileURL)
        } else {
            try data.write(to: fileURL)
        }
    }
    
    private func retrieveFromDisk<T: Codable>(type: T.Type, key: String) throws -> CacheEntry<T>? {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).cache")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        
        let decompressedData: Data
        if configuration.compressionEnabled {
            decompressedData = try (data as NSData).decompressed(using: .lzfse) as Data
        } else {
            decompressedData = data
        }
        
        return try JSONDecoder().decode(CacheEntry<T>.self, from: decompressedData)
    }
    
    private func removeFromDisk(key: String) throws {
        let fileURL = diskCacheURL.appendingPathComponent("\(key).cache")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    // MARK: - Preload Methods (Mock implementations)
    
    private func preloadWeatherData(for location: CLLocationCoordinate2D) async throws -> SafetyData? {
        // Mock implementation - in real app, this would call the weather API
        return nil
    }
    
    private func preloadCrimeData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData? {
        // Mock implementation - in real app, this would call the crime data API
        return nil
    }
    
    private func preloadCityServiceData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData? {
        // Mock implementation - in real app, this would call the city service API
        return nil
    }
    
    private func preloadTrafficData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData? {
        // Mock implementation - in real app, this would call the traffic API
        return nil
    }
    
    // MARK: - Published Properties
    @Published var isCacheEnabled = true
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Cache Manager Extensions

extension DataCacheManager {
    
    /// Export cache statistics for debugging
    func exportStatistics() -> String {
        let stats = statistics
        return """
        📊 Cache Statistics
        ==================
        Memory Items: \(stats.memoryItems)
        Disk Items: \(stats.diskItems)
        Total Items: \(stats.totalItems)
        Memory Size: \(ByteCountFormatter.string(fromByteCount: stats.memorySize, countStyle: .memory))
        Disk Size: \(ByteCountFormatter.string(fromByteCount: stats.diskSize, countStyle: .file))
        Hit Rate: \(String(format: "%.1f", stats.hitRate * 100))%
        Miss Rate: \(String(format: "%.1f", stats.missRate * 100))%
        Efficiency: \(String(format: "%.1f", stats.efficiency * 100))%
        Evictions: \(stats.evictionCount)
        Last Cleanup: \(DateFormatter.localizedString(from: stats.lastCleanup, dateStyle: .short, timeStyle: .medium))
        """
    }
    
    /// Optimize cache based on usage patterns
    func optimizeCache() async throws {
        print("🔧 Optimizing cache based on usage patterns...")
        
        // Analyze access patterns and adjust cache configuration
        let efficiency = statistics.efficiency
        
        if efficiency < 0.5 {
            // Low hit rate, increase cache size
            print("⚡ Low cache efficiency (\(String(format: "%.1f", efficiency * 100))%), increasing cache size")
            
            memoryCache.countLimit = Int(Double(configuration.memoryMaxItems) * 1.5)
        } else if efficiency > 0.8 {
            // High hit rate, cache is well-tuned
            print("✅ High cache efficiency (\(String(format: "%.1f", efficiency * 100))%), cache is well-optimized")
        }
        
        // Perform cleanup
        try await performCleanup()
        
        print("🎯 Cache optimization complete")
    }
}
