//
//  ClusterManager.swift
//  Userapp
//
//  Created by Ri on 8/20/25.
//


import Foundation
import RealmSwift
import CoreLocation

class ClusterManager {
    static let shared = ClusterManager()
    private init() {}
    
    func getClusters() -> [[LocationVisit]] {
        let realm = try! Realm()
        let visits = realm.objects(LocationVisit.self)
        
        // Filter visits with duration >= 45 min
        let validVisits = visits.filter { $0.durationMinutes >= 45 }
        
        // Group by approximate location (700m radius)
        var clusters: [[LocationVisit]] = []
        
        for visit in validVisits {
            var added = false
            for i in 0..<clusters.count {
                if let first = clusters[i].first {
                    let loc1 = CLLocation(latitude: first.latitude, longitude: first.longitude)
                    let loc2 = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
                    let distance = loc1.distance(from: loc2)
                    
                    if distance <= 700 {
                        clusters[i].append(visit)
                        added = true
                        break
                    }
                }
            }
            if !added {
                clusters.append([visit])
            }
        }
        
        // Keep only clusters where visit count >= 3
        let strongClusters = clusters.filter { $0.count >= 3 }
        return strongClusters
    }
}
