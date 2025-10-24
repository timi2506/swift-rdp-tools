import Foundation

public struct RDPKey: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String
    
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    
    public static let username: RDPKey = "username"
    public static let fullAddress: RDPKey = "full address"
}

public enum RDPValue: Hashable, RawRepresentable {
    public init?(rawValue: any RDPCodable) {
        if let int = rawValue as? Int {
            self = .int(int)
        } else if let data = rawValue as? Data {
            self = .binary(data)
        } else if let string = rawValue as? String {
            self = .string(string)
        } else {
            return nil
        }
    }
    
    case int(Int)
    case string(String)
    case binary(Data)
    fileprivate var character: Character {
        switch self {
            case .int(let value):
                value.character
            case .string(let value):
                value.character
            case .binary(let value):
                value.character
        }
    }
    fileprivate var encodingValue: String {
        switch self {
            case .int(let value):
                value.encodingValue
            case .string(let value):
                value.encodingValue
            case .binary(let value):
                value.encodingValue
        }
    }
    public var rawValue: RDPCodable {
        switch self {
            case .int(let int):
                return int
            case .string(let string):
                return string
            case .binary(let data):
                return data
        }
    }
}

public class RDPFileDecoder {
    public init() {}

    public func decode(from rdpFileContents: String) throws -> [RDPKey: RDPValue] {
        var values: [RDPKey: RDPValue] = [:]
        let lines = rdpFileContents
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 2).map(String.init)
            
            guard parts.count == 2 || parts.count == 3 else {
                print("Invalid parts in line:", line)
                throw RDPCodingError.invalidFile
            }
            
            let key = RDPKey(rawValue: parts[0])
            let type = parts[1]
            let value = parts.count == 2 ? nil : parts[2]
            
            do {
                var valueType: RDPValue?
                switch type {
                    case "s": valueType = try String.decode(from: value)
                    case "i": valueType = try Int.decode(from: value)
                    case "b": valueType = try Data.decode(from: value)
                    default:
                        print("Invalid type:", type, "in line:", line)
                        throw RDPCodingError.invalidFile
                }
                guard let valueType else {
                    print("ValueType nil for line:", line)
                    throw RDPCodingError.unknown
                }
                values[key] = valueType
            } catch {
                print("Failed decoding line:", line)
                throw error
            }
        }
        return values
    }
    public func decode(from rdpFileContents: Data) throws -> [RDPKey: RDPValue] {
        guard let fileContents = String(data: rdpFileContents, encoding: .utf16LittleEndian)
                ?? String(data: rdpFileContents, encoding: .utf8)
                ?? String(data: rdpFileContents, encoding: .unicode) else {
            throw RDPCodingError.invalidFile
        }
        return try self.decode(from: fileContents)
    }
}

public class RDPFileEncoder {
    public init() {}

    public func encode(_ values: [RDPKey: RDPValue]) throws -> Data {
        guard let data = values.map({ (key, value) in
            "\(key):\(value.character):\(value.encodingValue)"
        }).joined(separator: "\n").data(using: .utf8) else {
            throw RDPCodingError.encodingError
        }
        return data
    }
}

public protocol RDPCodable: RDPEncodable, RDPDecodable {
    var character: Character { get }
}

public protocol RDPEncodable {
    var encodingValue: String { get }
}

extension RDPEncodable where Self: RDPCodable {
    func encode(with key: RDPKey) -> String {
        "\(key):\(character):\(self)"
    }
}

public protocol RDPDecodable {
    static func decode(from: String?) throws -> RDPValue
}

extension Int: RDPCodable {
    public var encodingValue: String { "\(self)" }
    
    public var character: Character {
        "i"
    }
    
    public static func decode(from string: String?) throws -> RDPValue {
        guard let string else { throw RDPCodingError.invalidString }
        if let int = Int(string) {
            return .int(int)
        } else {
            throw RDPCodingError.invalidString
        }
    }
}

extension String: RDPCodable {
    public var encodingValue: String {
        self
    }
    
    public var character: Character {
        "s"
    }
    
    public static func decode(from string: String?) throws -> RDPValue {
        return .string(string ?? "")
    }
}

extension Data: RDPCodable {
    public var encodingValue: String {
        self.hexString
    }
    
    public var character: Character {
        "b"
    }
    
    public static func decode(from string: String?) throws -> RDPValue {
        guard let string else { throw RDPCodingError.invalidString }
        if let data = Data(hexString: string) {
            return .binary(data)
        } else {
            throw RDPCodingError.invalidString
        }
    }
    
    private init?(hexString: String) {
        let cleaned = hexString.replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0 else { return nil }
        var data = Data()
        var idx = cleaned.startIndex
        while idx < cleaned.endIndex {
            let next = cleaned.index(idx, offsetBy: 2)
            guard let byte = UInt8(cleaned[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        self = data
    }
    private var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }
}

enum RDPCodingError: LocalizedError {
    case invalidString
    case invalidFile
    case encodingError
    case unknown
    
    var errorDescription: String? {
        switch self {
            case .invalidString:
                return "Invalid string value — cannot decode to any known RDP type."
            case .invalidFile:
                return "Invalid RDP file format (expected key:type:value per line)."
            case .encodingError:
                return "An unknown error occurred while encoding."
            case .unknown:
                return "Unknown decoding error — possibly malformed or unexpected data."
        }
    }
}

extension RDPCodingError: CustomNSError {
    public static var errorDomain: String { "RDPTools.RDPCodingError" }
    
    public var errorCode: Int {
        switch self {
            case .invalidString: return 1
            case .invalidFile: return 2
            case .encodingError: return 3
            case .unknown: return 999
        }
    }
    
    public var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: errorDescription ?? "Unknown error"]
    }
}
