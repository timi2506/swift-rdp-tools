import Foundation

public struct RDPKey: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String
    
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    
    public static let username: RDPKey = "username"
    public static let fullAddress: RDPKey = "full address"
}

public enum RDPValue: Hashable {
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
}

public class RDPFileDecoder {
    public init() {}

    public func decode(from rdpFileContents: String) throws -> [RDPKey: RDPValue] {
        var values: [RDPKey: RDPValue] = [:]
        let lines = rdpFileContents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 2).map(String.init)
            
            guard parts.count == 3 else {
                throw RDPCodingError.invalidFile
            }
        
            let key = RDPKey(rawValue: parts[0])
            let type = parts[1]
            let value = parts[2]
            
            var valueType: RDPValue?
            switch type {
                case "s": valueType = try String.decode(from: value)
                case "i": valueType = try Int.decode(from: value)
                case "b": valueType = try Data.decode(from: value)
                default: throw RDPCodingError.invalidFile
            }
            guard let valueType else { throw RDPCodingError.unknown }
            values[key] = valueType
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

protocol RDPCodable: RDPEncodable, RDPDecodable {
    var character: Character { get }
}

protocol RDPEncodable {
    var encodingValue: String { get }
}

extension RDPEncodable where Self: RDPCodable {
    func encode(with key: RDPKey) -> String {
        "\(key):\(character):\(self)"
    }
}

protocol RDPDecodable {
    static func decode(from: String) throws -> RDPValue
}

extension Int: RDPCodable {
    var encodingValue: String { "\(self)" }
    
    var character: Character {
        "i"
    }
    
    static func decode(from string: String) throws -> RDPValue {
        if let int = Int(string) {
            return .int(int)
        } else {
            throw RDPCodingError.invalidString
        }
    }
}

extension String: RDPCodable {
    var encodingValue: String {
        self
    }
    
    var character: Character {
        "s"
    }
    
    static func decode(from string: String) throws -> RDPValue {
        return .string(string)
    }
}

extension Data: RDPCodable {
    var encodingValue: String {
        self.hexString
    }
    
    var character: Character {
        "b"
    }
    
    static func decode(from string: String) throws -> RDPValue {
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
    var localizedDescription: String? {
        switch self {
            case .invalidString:
                "String invalid for decoding to any RDPCodingValue, valid strings: integer strings, hex binary strings, strings"
            case .invalidFile:
                "Not a Valid RDP File"
            case .encodingError:
                "An Unknown Error occured while encoding"
            case .unknown: nil
        }
    }
}
