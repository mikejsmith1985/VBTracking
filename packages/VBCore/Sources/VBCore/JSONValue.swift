// A JSON value, as it actually arrives.
//
// The log this app reads was written by the shipped web app, where an event is a plain
// object. Migrations prepend and stamp fields on those objects without understanding them,
// and a file written by a newer build may carry fields this one has never heard of. So the
// storage layer keeps events as values rather than as types: what is on disk survives a
// round trip whether or not this build knows what it means.
//
// The reducer never sees this. It sees `Event`, decoded from here once at the boundary.
import Foundation

/// One JSON value: the six things JSON can be.
public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Reading

extension JSONValue {
    /// The string this value holds, or nil when it holds something else.
    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    /// The number this value holds as a whole number, or nil.
    ///
    /// A JSON number is a Double on the wire even when it was written as `3`, so a count
    /// that arrives as `3.0` is still a count. A fractional value is not, and returns nil.
    public var intValue: Int? {
        guard case let .number(value) = self, value.rounded() == value else { return nil }
        return Int(value)
    }

    /// The boolean this value holds, or nil. Never coerced: `1` is not `true` here.
    public var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    /// The array this value holds, or nil.
    public var arrayValue: [JSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }

    /// The object this value holds, or nil.
    public var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    /// True when the value is JSON null. An absent key and a null are the same to us.
    public var isNull: Bool { self == .null }
}

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a JSON value."
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .number(value): try encodeNumber(value, into: &container)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }

    /// Writes a whole number as a whole number.
    ///
    /// Without this a count read as `3` is written back as `3.0`, and a log that went
    /// through this app would no longer be byte-comparable with one that did not — which
    /// is exactly what the parity suite is checking.
    private func encodeNumber(
        _ value: Double,
        into container: inout SingleValueEncodingContainer
    ) throws {
        if value.rounded() == value, value.magnitude < 9_007_199_254_740_992 {
            try container.encode(Int(value))
        } else {
            try container.encode(value)
        }
    }
}

// MARK: - Convenience

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
