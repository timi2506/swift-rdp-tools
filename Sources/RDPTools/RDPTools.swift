import Foundation

public struct RDPValue: Identifiable, Hashable {
    @frozen public enum Value: Hashable {
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
    public var key: String
    public var value: Value
    public var id: String { key }
    fileprivate func encode() -> String {
        return "\(key):\(value.character):\(value.encodingValue)"
    }
}

public class RDPFileDecoder {
    public init() {}

    public func decode(from rdpFileContents: String) throws -> [RDPValue] {
        var values: [RDPValue] = []
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
            
            let key = parts[0]
            let type = parts[1]
            let value = parts[2]
            
            var valueType: RDPValue.Value?
            switch type {
                case "s": valueType = try String.decode(from: value)
                case "i": valueType = try Int.decode(from: value)
                case "b": valueType = try Data.decode(from: value)
                default: throw RDPCodingError.invalidFile
            }
            guard let valueType else { throw RDPCodingError.unknown }
            values.append(RDPValue(key: key, value: valueType))
        }
        return values
    }
    public func decode(from rdpFileContents: Data) throws -> [RDPValue] {
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

    public func encode(_ values: [RDPValue]) throws -> Data {
        guard let data = values.map({ $0.encode() }).joined(separator: "\n").data(using: .utf8) else {
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
    func encode(with key: String) -> String {
        "\(key):\(character):\(self)"
    }
}

protocol RDPDecodable {
    static func decode(from: String) throws -> RDPValue.Value
}

extension Int: RDPCodable {
    var encodingValue: String { "\(self)" }
    
    var character: Character {
        "i"
    }
    
    static func decode(from string: String) throws -> RDPValue.Value {
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
    
    static func decode(from string: String) throws -> RDPValue.Value {
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
    
    static func decode(from string: String) throws -> RDPValue.Value {
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
