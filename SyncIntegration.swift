import Foundation
import UIKit
import FirebaseFirestore

class SyncIntegration {
    
    static let shared = SyncIntegration()
    private init() {}
    
    // MARK: - Complete Sync Flow
    
    /// Perform both upload (cloud sync) and download (device sync)
    func performCompleteSync(for userId: String, completion: @escaping (Result<SyncResult, Error>) -> Void) {
        print("Starting complete sync for user: \(userId)")
        
        // Step 1: Upload any pending snapshots to cloud
        SyncManager.shared.syncPendingSnapshots { uploadResult in
            switch uploadResult {
            case .success(let uploadedCount):
                print("Uploaded \(uploadedCount) snapshots to cloud")
                
                // Step 2: Download and restore latest snapshots from cloud
                DeviceSyncManager.shared.syncFromCloud(for: userId) { downloadResult in
                    switch downloadResult {
                    case .success(let downloadedCount):
                        print("Downloaded and restored \(downloadedCount) snapshots from cloud")
                        
                        let result = SyncResult(
                            uploadedCount: uploadedCount,
                            downloadedCount: downloadedCount,
                            totalSynced: uploadedCount + downloadedCount
                        )
                        completion(.success(result))
                        
                    case .failure(let error):
                        print("Download sync failed: \(error)")
                        
                        // Even if download fails, upload might have succeeded
                        let partialResult = SyncResult(
                            uploadedCount: uploadedCount,
                            downloadedCount: 0,
                            totalSynced: uploadedCount
                        )
                        completion(.success(partialResult))
                    }
                }
                
            case .failure(let error):
                print("Upload sync failed: \(error)")
                
                // Try download even if upload failed
                DeviceSyncManager.shared.syncFromCloud(for: userId) { downloadResult in
                    switch downloadResult {
                    case .success(let downloadedCount):
                        let partialResult = SyncResult(
                            uploadedCount: 0,
                            downloadedCount: downloadedCount,
                            totalSynced: downloadedCount
                        )
                        completion(.success(partialResult))
                        
                    case .failure:
                        completion(.failure(error)) // Return the original upload error
                    }
                }
            }
        }
    }
    
    /// Perform only device sync (download from cloud)
    func performDeviceSync(for userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        print("Starting device sync (download only) for user: \(userId)")
        DeviceSyncManager.shared.syncFromCloud(for: userId, completion: completion)
    }
    
    /// Perform only cloud sync (upload to cloud)
    func performCloudSync(completion: @escaping (Result<Int, Error>) -> Void) {
        print("Starting cloud sync (upload only)")
        SyncManager.shared.syncPendingSnapshots(completion: completion)
    }
    
    /// Check if user has any cloud snapshots available
    func hasCloudSnapshots(for userId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let metadataRef = db.collection("ciphertext_metadata").document("\(userId)")
        
        metadataRef.getDocument { document, error in
            let hasSnapshots = document?.exists == true && error == nil
            DispatchQueue.main.async {
                completion(hasSnapshots)
            }
        }
    }
}

// MARK: - Integration with App Lifecycle
extension SyncIntegration {
    
    /// Call this on app launch to sync device with cloud data
    func syncOnAppLaunch(for userId: String) {
        guard !userId.isEmpty else {
            print("Cannot sync: No user ID")
            return
        }
        
        print("App launch sync triggered")
        
        // Check if cloud snapshots exist first
        hasCloudSnapshots(for: userId) { hasSnapshots in
            if hasSnapshots {
                self.performCompleteSync(for: userId) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let syncResult):
                            print("App launch sync completed successfully")
                            print("Sync Summary: ↑\(syncResult.uploadedCount) ↓\(syncResult.downloadedCount)")
                            
                        case .failure(let error):
                            print("App launch sync failed: \(error)")
                        }
                    }
                }
            } else {
                print("No cloud snapshots found for user, skipping device sync")
                // Just perform cloud sync to upload any pending local snapshots
                self.performCloudSync { result in
                    switch result {
                    case .success(let count):
                        print("Initial cloud sync completed: \(count) snapshots uploaded")
                    case .failure(let error):
                        print("Initial cloud sync failed: \(error)")
                    }
                }
            }
        }
    }
    
    /// Call this when user logs in on a new device
    func syncNewDevice(for userId: String, completion: @escaping (Bool) -> Void) {
        print("New device sync triggered")
        
        performDeviceSync(for: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    print("New device sync completed: \(count) snapshots restored")
                    completion(true)
                    
                case .failure(let error):
                    print("New device sync failed: \(error)")
                    completion(false)
                }
            }
        }
    }
    
    /// Trigger sync after security question setup
    func syncAfterSecuritySetup(for userId: String) {
        print("Post-security setup sync triggered")
        
        performCloudSync { result in
            switch result {
            case .success(let count):
                print("Post-setup sync completed: \(count) snapshots uploaded")
            case .failure(let error):
                print("Post-setup sync failed: \(error)")
            }
        }
    }
}

// MARK: - Data Models
struct SyncResult {
    let uploadedCount: Int      // Snapshots uploaded to cloud
    let downloadedCount: Int    // Snapshots downloaded from cloud
    let totalSynced: Int        // Total synchronized items
}

// MARK: - Integration with HomeViewController
extension HomeViewController {
    
    /// Call this method to trigger device sync from your test button
    func triggerDeviceSync() {
        guard !userId.isEmpty else {
            showTestAlert("Error", "No user ID available")
            return
        }
        
        print("Manual device sync triggered from HomeViewController")
        
        SyncIntegration.shared.performDeviceSync(for: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    self.showTestAlert("Sync Complete", "Successfully restored \(count) snapshots from cloud")
                    
                case .failure(let error):
                    self.showTestAlert("Sync Failed", "Device sync failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Call this method to trigger complete sync (upload + download)
    func triggerCompleteSync() {
        guard !userId.isEmpty else {
            showTestAlert("Error", "No user ID available")
            return
        }
        
        print("Manual complete sync triggered from HomeViewController")
        
        SyncIntegration.shared.performCompleteSync(for: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let syncResult):
                    let message = "Uploaded: \(syncResult.uploadedCount)\nDownloaded: \(syncResult.downloadedCount)"
                    self.showTestAlert("Sync Complete", message)
                    
                case .failure(let error):
                    self.showTestAlert("Sync Failed", "Complete sync failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Helper method for alerts in extension
    private func showTestAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
