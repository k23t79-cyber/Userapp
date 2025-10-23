//
//  MotionState.swift
//  Userapp
//
//  Created by Ri on 10/11/25.
//


import Foundation
import CoreMotion

// MARK: - Motion State Enum
enum MotionState: String, Codable {
    case moving = "moving"
    case still = "still"
    case unknown = "unknown"
}

// MARK: - Gyroscope Manager
final class GyroscopeManager {
    
    static let shared = GyroscopeManager()
    
    // MARK: - Properties
    private let motionManager = CMMotionManager()
    private var currentMotionState: MotionState = .unknown
    private var lastRotationRate: CMRotationRate?
    private var isMonitoring = false
    
    // Thresholds for motion detection
    private let stillThreshold: Double = 0.1  // Radians per second
    private let movingThreshold: Double = 0.5 // Radians per second
    private let updateInterval: TimeInterval = 0.2 // 5 times per second
    
    private init() {
        configureMotionManager()
    }
    
    // MARK: - Configuration
    private func configureMotionManager() {
        guard motionManager.isGyroAvailable else {
            print("⚠️ GYROSCOPE: Not available on this device")
            currentMotionState = .unknown
            return
        }
        
        motionManager.gyroUpdateInterval = updateInterval
        print("✅ GYROSCOPE: Manager configured")
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring gyroscope data
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ GYROSCOPE: Already monitoring")
            return
        }
        
        guard motionManager.isGyroAvailable else {
            print("⚠️ GYROSCOPE: Not available - cannot start monitoring")
            currentMotionState = .unknown
            return
        }
        
        motionManager.startGyroUpdates(to: .main) { [weak self] (gyroData, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ GYROSCOPE: Error - \(error.localizedDescription)")
                self.currentMotionState = .unknown
                return
            }
            
            guard let data = gyroData else {
                self.currentMotionState = .unknown
                return
            }
            
            self.processGyroData(data.rotationRate)
        }
        
        isMonitoring = true
        print("📡 GYROSCOPE: Monitoring started")
    }
    
    /// Stop monitoring gyroscope data
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        motionManager.stopGyroUpdates()
        isMonitoring = false
        print("🛑 GYROSCOPE: Monitoring stopped")
    }
    
    /// Get current motion state (synchronous)
    func getCurrentMotionState() -> MotionState {
        return currentMotionState
    }
    
    /// Get detailed motion metrics
    func getMotionMetrics() -> [String: Any] {
        var metrics: [String: Any] = [
            "state": currentMotionState.rawValue,
            "isAvailable": motionManager.isGyroAvailable,
            "isMonitoring": isMonitoring
        ]
        
        if let rotation = lastRotationRate {
            let magnitude = calculateMagnitude(rotation)
            metrics["magnitude"] = magnitude
            metrics["x"] = rotation.x
            metrics["y"] = rotation.y
            metrics["z"] = rotation.z
        }
        
        return metrics
    }
    
    /// Take a snapshot reading (useful for trust verification)
    func captureMotionSnapshot(duration: TimeInterval = 1.0, completion: @escaping (MotionState, Double) -> Void) {
        guard motionManager.isGyroAvailable else {
            completion(.unknown, 0.0)
            return
        }
        
        var samples: [Double] = []
        let sampleInterval: TimeInterval = 0.1
        let numberOfSamples = Int(duration / sampleInterval)
        
        var sampleCount = 0
        
        motionManager.gyroUpdateInterval = sampleInterval
        motionManager.startGyroUpdates(to: .main) { [weak self] (gyroData, error) in
            guard let self = self else { return }
            
            if let data = gyroData {
                let magnitude = self.calculateMagnitude(data.rotationRate)
                samples.append(magnitude)
                sampleCount += 1
                
                if sampleCount >= numberOfSamples {
                    self.motionManager.stopGyroUpdates()
                    
                    // Calculate average magnitude
                    let avgMagnitude = samples.reduce(0.0, +) / Double(samples.count)
                    
                    // Determine state based on average
                    let state: MotionState
                    if avgMagnitude < self.stillThreshold {
                        state = .still
                    } else if avgMagnitude >= self.movingThreshold {
                        state = .moving
                    } else {
                        // In between threshold - check variance
                        let variance = self.calculateVariance(samples)
                        state = variance > 0.05 ? .moving : .still
                    }
                    
                    completion(state, avgMagnitude)
                    
                    // Restart continuous monitoring if it was running
                    if self.isMonitoring {
                        self.startMonitoring()
                    }
                }
            } else if let error = error {
                print("❌ GYROSCOPE SNAPSHOT: Error - \(error.localizedDescription)")
                self.motionManager.stopGyroUpdates()
                completion(.unknown, 0.0)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func processGyroData(_ rotation: CMRotationRate) {
        lastRotationRate = rotation
        
        // Calculate magnitude of rotation (Euclidean norm)
        let magnitude = calculateMagnitude(rotation)
        
        // Determine motion state based on magnitude
        if magnitude < stillThreshold {
            currentMotionState = .still
        } else if magnitude >= movingThreshold {
            currentMotionState = .moving
        } else {
            // In the middle - keep previous state or set to still by default
            if currentMotionState == .unknown {
                currentMotionState = .still
            }
        }
    }
    
    private func calculateMagnitude(_ rotation: CMRotationRate) -> Double {
        return sqrt(rotation.x * rotation.x + 
                   rotation.y * rotation.y + 
                   rotation.z * rotation.z)
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        
        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0.0, +) / Double(values.count)
    }
    
    // MARK: - Trust Score Contribution
    
    /// Calculate trust score contribution from motion state
    /// Returns a score between 0-10
    func getTrustScoreContribution() -> Int {
        switch currentMotionState {
        case .still:
            // Device is still - higher trust (user is stationary, likely authentic)
            return 8
        case .moving:
            // Device is moving - moderate trust (could be walking, normal use)
            return 6
        case .unknown:
            // No gyroscope data - neutral
            return 5
        }
    }
    
    /// Get detailed trust assessment
    func getTrustAssessment() -> String {
        switch currentMotionState {
        case .still:
            return "Device stationary - consistent with focused user activity"
        case .moving:
            return "Device in motion - consistent with mobile user"
        case .unknown:
            return "Motion data unavailable"
        }
    }
}

// MARK: - Motion Data Model (for Realm storage)
import RealmSwift

class MotionData: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var userId: String = ""
    @Persisted var timestamp: Date = Date()
    @Persisted var motionStateRaw: String = MotionState.unknown.rawValue
    @Persisted var magnitude: Double = 0.0
    @Persisted var rotationX: Double = 0.0
    @Persisted var rotationY: Double = 0.0
    @Persisted var rotationZ: Double = 0.0
    
    var motionState: MotionState {
        get { MotionState(rawValue: motionStateRaw) ?? .unknown }
        set { motionStateRaw = newValue.rawValue }
    }
    
    convenience init(userId: String, state: MotionState, magnitude: Double, rotation: CMRotationRate) {
        self.init()
        self.userId = userId
        self.motionState = state
        self.magnitude = magnitude
        self.rotationX = rotation.x
        self.rotationY = rotation.y
        self.rotationZ = rotation.z
        self.timestamp = Date()
    }
}