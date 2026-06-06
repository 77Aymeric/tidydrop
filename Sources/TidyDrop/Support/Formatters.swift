import Foundation

enum Formatters {
    static func bytes(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func basename(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
