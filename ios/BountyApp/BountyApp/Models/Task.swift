import Foundation

struct TaskItem: Codable, Identifiable {
    let id: String
    let publisherID: String
    let title: String
    let description: String
    let targetLat: Double
    let targetLng: Double
    let targetAddr: String
    let radius: Int
    let timeLimit: Int
    let bountyBeans: Int
    var status: String
    let createdAt: String
    let updatedAt: String
    let distance: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, description, radius, status, distance
        case publisherID = "publisher_id"
        case targetLat = "target_lat"
        case targetLng = "target_lng"
        case targetAddr = "target_addr"
        case timeLimit = "time_limit"
        case bountyBeans = "bounty_beans"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Submission

struct Submission: Codable {
    let id: String
    let taskID: String
    let claimerID: String
    let note: String
    let photos: [SubmissionPhoto]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, note, photos
        case taskID = "task_id"
        case claimerID = "claimer_id"
        case createdAt = "created_at"
    }
}

struct SubmissionPhoto: Codable, Identifiable {
    let id: String
    let url: String
    let latitude: Double
    let longitude: Double
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case id, url, latitude, longitude
        case timestamp = "photo_timestamp"
    }
}

// MARK: - Task Message (conversation)

struct TaskMessage: Codable, Identifiable {
    let id: String
    let taskID: String
    let senderID: String
    let content: String
    let imageURLs: [String]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, content
        case taskID = "task_id"
        case senderID = "sender_id"
        case imageURLs = "image_urls"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        taskID = try container.decode(String.self, forKey: .taskID)
        senderID = try container.decode(String.self, forKey: .senderID)
        content = try container.decode(String.self, forKey: .content)
        imageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs) ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }

    var isImageOnly: Bool { content.isEmpty && !imageURLs.isEmpty }
}

// MARK: - Submit Evidence

struct SubmitEvidenceRequest: Codable {
    let note: String
    let photos: [PhotoInfo]
    let submitLat: Double
    let submitLng: Double
}

struct PhotoInfo: Codable {
    let url: String
    let latitude: Double
    let longitude: Double
    let timestamp: String
}

// MARK: - Upload Response

struct UploadImageResponse: Codable {
    let url: String
}
