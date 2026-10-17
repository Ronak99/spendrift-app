//
//  BackupModels.swift
//  Spendrift
//
//  Wire format for device backups (`/v1/backups`). A snapshot is a plain copy
//  of every account, category, and transaction; transactions point at their
//  account and category by id, so the links survive the round trip.
//
//  The server stores these records as one JSON document and hands them back
//  untouched, so this file is the only definition of the format. A field added
//  later must be optional or have a default, or older backups stop decoding.
//  A change older builds cannot read safely must bump `BackupSnapshot.schemaVersion`.
//

import Foundation

struct BackupAccountRecord: Codable, Equatable {
    let id: UUID
    let name: String
    let balance: Double
    /// `AccountIcon` raw value. Kept as text so a backup from a newer build with
    /// an icon this build does not know still restores.
    let icon: String
    let isPrimary: Bool
    let createdOn: Date
    let lastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, balance, icon
        case isPrimary = "is_primary"
        case createdOn = "created_on"
        case lastUsedAt = "last_used_at"
    }
}

struct BackupCategoryRecord: Codable, Equatable {
    let id: UUID
    let name: String
    let type: CategoryType
    /// `CategoryIcon` raw value, text for the same reason as the account icon.
    let icon: String
    let isDefault: Bool
    let sortOrder: Int
    let colorHex: String?
    /// Monthly cap. Optional so backups written before budgets restore as uncapped.
    let monthlyBudget: Double?
    let createdOn: Date
    let lastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, type, icon
        case isDefault = "is_default"
        case sortOrder = "sort_order"
        case colorHex = "color_hex"
        case monthlyBudget = "monthly_budget"
        case createdOn = "created_on"
        case lastUsedAt = "last_used_at"
    }
}

struct BackupTransactionRecord: Codable, Equatable {
    let id: UUID
    let notes: String
    let amount: Double
    let date: Date
    let transactionType: TransactionType
    let source: String
    let accountID: UUID?
    let categoryID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, notes, amount, source
        case date = "transaction_date"
        case transactionType = "transaction_type"
        case accountID = "account_id"
        case categoryID = "category_id"
    }
}

/// Everything a backup carries. Also the unit a restore writes back.
struct BackupSnapshot: Equatable {
    /// Version of the record format this build writes, and the newest it can restore.
    static let schemaVersion = 1

    var accounts: [BackupAccountRecord]
    var categories: [BackupCategoryRecord]
    var transactions: [BackupTransactionRecord]
}

/// One stored backup as listed in Settings: when it was taken and its size.
struct BackupSummary: Decodable, Equatable, Identifiable {
    let id: UUID
    let appVersion: String
    let schemaVersion: Int
    let accountCount: Int
    let categoryCount: Int
    let transactionCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case appVersion = "app_version"
        case schemaVersion = "schema_version"
        case accountCount = "account_count"
        case categoryCount = "category_count"
        case transactionCount = "transaction_count"
        case createdAt = "created_at"
    }
}

// MARK: - Requests and responses

/// `POST /v1/backups` body.
struct BackupCreateRequest: Encodable {
    let deviceID: String
    let appVersion: String
    let schemaVersion: Int
    let accounts: [BackupAccountRecord]
    let categories: [BackupCategoryRecord]
    let transactions: [BackupTransactionRecord]

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case appVersion = "app_version"
        case schemaVersion = "schema_version"
        case accounts, categories, transactions
    }
}

/// `POST /v1/backups` response.
struct BackupCreateResponse: Decodable {
    let backup: BackupSummary
}

/// `GET /v1/backups` response.
struct BackupListResponse: Decodable {
    let backups: [BackupSummary]
}

/// `GET /v1/backups/{id}` response.
struct BackupDetailResponse: Decodable {
    let backup: BackupSummary
    let accounts: [BackupAccountRecord]
    let categories: [BackupCategoryRecord]
    let transactions: [BackupTransactionRecord]

    var snapshot: BackupSnapshot {
        BackupSnapshot(accounts: accounts, categories: categories, transactions: transactions)
    }
}

// MARK: - Coding

/// JSON coders for the backup routes. Dates travel as ISO 8601 in UTC with
/// milliseconds, the one shape the backend accepts and returns.
enum BackupCoding {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractionalFormatter.string(from: date))
        }
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = fractionalFormatter.date(from: string)
                ?? wholeSecondFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognised backup timestamp: \(string)"
            )
        }
        return decoder
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSecondFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
