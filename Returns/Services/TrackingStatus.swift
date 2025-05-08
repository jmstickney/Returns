//
//  TrackingStatus.swift
//  Returns
//
//  Created by Jonathan Stickney on 3/28/25.
//


import Foundation

enum TrackingStatus: String, Codable {
    case unknown = "Unknown"
    case inTransit = "In Transit"
    case outForDelivery = "Out for Delivery"
    case delivered = "Delivered"
    case exception = "Exception"
    case pending = "Pending"
    
    var iconName: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .inTransit: return "shippingbox"
        case .outForDelivery: return "truck"
        case .delivered: return "checkmark.circle"
        case .exception: return "exclamationmark.triangle"
        case .pending: return "clock"
        }
    }
    
    var color: String {
        switch self {
        case .unknown: return "gray"
        case .inTransit: return "blue"
        case .outForDelivery: return "orange"
        case .delivered: return "green"
        case .exception: return "red"
        case .pending: return "purple"
        }
    }
    
    // Map Shippo tracking statuses to our app's statuses
    static func fromShippoStatus(_ status: String) -> TrackingStatus {
        switch status.uppercased() {
        case "PRE_TRANSIT":
                return .pending
            case "TRANSIT":
                return .inTransit
            case "DELIVERED":
                return .delivered
            case "RETURNED":
                return .exception
            case "FAILURE":
                return .exception
            case "UNKNOWN":
                return .unknown
            default:
                return .unknown
        }
    }
}

struct TrackingDetail: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var location: String
    var activity: String
}

struct TrackingInfo: Codable {
    var trackingNumber: String
    var carrier: String
    var status: TrackingStatus
    var estimatedDelivery: Date?
    var lastUpdated: Date
    var details: [TrackingDetail]
}

class TrackingService {
    static let shared = TrackingService()
    
    // Replace with your actual Shippo API key
    private let shippoApiKey = "shippo_live_005dcab66bcb0269d57300a4fa7560c2f14dae59"
    
    private let cache = NSCache<NSString, NSData>()
    private let cacheExpirationTime: TimeInterval = 30 * 60 // 30 minutes
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
    }
    
    func fetchTrackingInfo(trackingNumber: String, completion: @escaping (Result<TrackingInfo, Error>) -> Void) {
        // Check cache first
        let cacheKey = NSString(string: trackingNumber)
        if let cachedData = cache.object(forKey: cacheKey) as Data? {
            do {
                let cachedInfo = try JSONDecoder().decode(CachedTrackingResponse.self, from: cachedData)
                
                // Check if cache is still valid
                if Date().timeIntervalSince(cachedInfo.timestamp) < cacheExpirationTime {
                    completion(.success(cachedInfo.trackingInfo))
                    return
                }
            } catch {
                print("Error decoding cached data: \(error)")
            }
        }
        
        // Detect carrier automatically or let Shippo do it
        let carrier = detectCarrier(for: trackingNumber)
        
        // Create URL request to Shippo API
        let urlString = "https://api.goshippo.com/tracks/\(carrier)/\(trackingNumber)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TrackingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("ShippoToken \(shippoApiKey)", forHTTPHeaderField: "Authorization")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "TrackingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    // For debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Shippo response: \(jsonString)")
                    }
                    
                    // Parse the Shippo response
                    let shippoResponse = try JSONDecoder().decode(ShippoTrackingResponse.self, from: data)
                    
                    // Convert Shippo response to our tracking info model
                    let trackingInfo = self.convertShippoResponseToTrackingInfo(shippoResponse)
                    
                    // Cache the result
                    let cachedResponse = CachedTrackingResponse(trackingInfo: trackingInfo, timestamp: Date())
                    do {
                        let data = try JSONEncoder().encode(cachedResponse)
                        self.cache.setObject(data as NSData, forKey: cacheKey)
                    } catch {
                        print("Error caching tracking data: \(error)")
                    }
                    
                    completion(.success(trackingInfo))
                } catch {
                    print("Error parsing tracking data: \(error)")
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    private func convertShippoResponseToTrackingInfo(_ response: ShippoTrackingResponse) -> TrackingInfo {
        // Create ISO date formatter for parsing dates
        let dateFormatter = ISO8601DateFormatter()
        
        // Convert tracking history to tracking details
        let details = response.trackingHistory.map { historyItem in
            return TrackingDetail(
                id: UUID(),
                date: dateFormatter.date(from: historyItem.statusDate) ?? Date(),
                location: formatLocation(historyItem.location),
                activity: historyItem.statusDetails ?? "Status update"
            )
        }
        
        // Parse estimated delivery date if available
        var estimatedDelivery: Date? = nil
        if let eta = response.eta {
            estimatedDelivery = dateFormatter.date(from: eta)
        }
        
        // Get the current status from tracking_status
        let currentStatus = TrackingStatus.fromShippoStatus(response.trackingStatus.status)
        
        return TrackingInfo(
            trackingNumber: response.trackingNumber,
            carrier: response.carrier,
            status: currentStatus,
            estimatedDelivery: estimatedDelivery,
            lastUpdated: Date(),
            details: details
        )
    }
    
    private func formatLocation(_ location: ShippoLocation?) -> String {
        guard let location = location else {
            return "Unknown Location"
        }
        
        var locationString = ""
        
        if let city = location.city {
            locationString += city
        }
        
        if let state = location.state {
            if !locationString.isEmpty {
                locationString += ", "
            }
            locationString += state
        }
        
        if let zip = location.zip {
            if !locationString.isEmpty {
                locationString += " "
            }
            locationString += zip
        }
        
        if locationString.isEmpty {
            if let country = location.country {
                locationString = country
            } else {
                locationString = "Unknown Location"
            }
        }
        
        return locationString
    }
    
    // Dictionary to map tracking number prefixes to carriers
    private let carrierPrefixes: [String: String] = [
        "1Z": "ups",
        "9400": "usps",
        "9205": "usps",
        "9407": "usps",
        "94": "usps",
        "92": "usps",
        "96": "usps",
        "93": "usps",
        "FDX": "fedex",
        "DHL": "dhl"
    ]
    
    func detectCarrier(for trackingNumber: String) -> String {
        for (prefix, carrier) in carrierPrefixes {
            if trackingNumber.hasPrefix(prefix) {
                return carrier
            }
        }
        
        // Check for FedEx pattern (all numeric, 12 or 15 digits)
        if trackingNumber.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
            if trackingNumber.count == 12 || trackingNumber.count == 15 {
                return "fedex"
            }
        }
        
        // If we can't detect it, let Shippo try to figure it out
        return "shippo"
    }
    
    // For caching
    private struct CachedTrackingResponse: Codable {
        let trackingInfo: TrackingInfo
        let timestamp: Date
    }
}

// MARK: - Shippo API Response Models
struct ShippoTrackingResponse: Codable {
    let carrier: String
    let trackingNumber: String
    let eta: String?
    let trackingStatus: ShippoTrackingStatus
    let trackingHistory: [ShippoTrackingHistoryItem]
    
    enum CodingKeys: String, CodingKey {
        case carrier
        case trackingNumber = "tracking_number"
        case eta
        case trackingStatus = "tracking_status"
        case trackingHistory = "tracking_history"
    }
}

struct ShippoTrackingStatus: Codable {
    let status: String
    let statusDetails: String?
    let statusDate: String
    let location: ShippoLocation?
    
    enum CodingKeys: String, CodingKey {
        case status
        case statusDetails = "status_details"
        case statusDate = "status_date"
        case location
    }
}

struct ShippoTrackingHistoryItem: Codable {
    let status: String
    let statusDetails: String?
    let statusDate: String
    let location: ShippoLocation?
    
    enum CodingKeys: String, CodingKey {
        case status
        case statusDetails = "status_details"
        case statusDate = "status_date"
        case location
    }
}

struct ShippoLocation: Codable {
    let city: String?
    let state: String?
    let zip: String?
    let country: String?
}
