import Foundation

nonisolated struct HealthDTO: Sendable {
    let status: String
    let version: String
    let time: String
}

nonisolated extension HealthDTO: Decodable {}
