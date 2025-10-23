// Models/DeviceSnapshot.swift
import Foundation

// PRIMARY device summary (stored in device_snapshots/{userId})
struct DeviceSnapshot: Codable {
    let userId: String
    let primaryDeviceId: String
    let trustScore: Float?
    let syncStatus: String?
    let lastUpdated: String?
    let createdAt: String?
}

// SECONDARY device history (stored in device_snapshots_history/{userId}/devices/{autoId})
struct DeviceSnapshotHistory: Codable {
    let userId: String
    let deviceId: String
    let isPrimary: Bool
    let trustScore: Float?
    let syncStatus: String?
    let snapshotData: String?
    let createdAt: String?
}

