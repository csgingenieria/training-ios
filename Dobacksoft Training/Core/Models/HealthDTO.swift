import Foundation

struct HealthDTO: Decodable, Sendable {
    let status: String
    let version: String
    let time: String
}
