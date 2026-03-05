//
//  Garage+CodableReference.swift
//  GarageStorage
//
//  Created by Brian Arnold on 10/7/19.
//  Copyright © 2015-2024 Wellframe. All rights reserved.
//

import Foundation

/// These encoding extensions are exposed to the Swift runtime, to ensure that references to any embedded `Identifiable` objects are correctly parked at the top level of the Garage.
/// Supports `Identifiable` where `ID` is `String`, `UUID`, or `LosslessStringConvertible`.
public extension KeyedEncodingContainer {
    
    /// Wraps the default `encode` implementation so that we can call it from our Identifiable version.
    private mutating func encodeDefault<T: Encodable>(_ codable: T, forKey key: KeyedEncodingContainer<K>.Key) throws {
        try encode(codable, forKey: key)
    }
    
    /// Encodes a nested `Identifiable` object as a reference.
    /// Supports `Identifiable` where `ID` is `String`, `UUID`, or `LosslessStringConvertible`.
    /// Falls back to default encoding if the `ID` type is not supported.
    mutating func encode<T: Encodable & Identifiable>(_ identifiable: T, forKey key: KeyedEncodingContainer<K>.Key) throws {
        // If this encoder does not have a garage, encode as Codable does.
        let encoder = superEncoder()
        guard let garage = encoder.garage else {
            try encodeDefault(identifiable, forKey: key)
            return
        }
        
        // Park the object and encode it as a reference.
        // If the ID type is unsupported, fall back to default encoding.
        do {
            let reference = try garage.extractIdentifierString(from: identifiable)
            try garage.parkEncodable(from: identifiable, identifier: reference)
            try encode(reference, forKey: key)
        } catch GarageError.unsupportedIDConformance {
            try encodeDefault(identifiable, forKey: key)
        }
    }

    /// Encodes a nested `Identifiable` object as a reference, if present.
    /// Supports `Identifiable` where `ID` is `String`, `UUID`, or `LosslessStringConvertible`.
    mutating func encodeIfPresent<T: Encodable & Identifiable>(_ identifiable: T?, forKey key: KeyedEncodingContainer<K>.Key) throws {
        guard let identifiable = identifiable else { return }
        try encode(identifiable, forKey: key)
    }
    
    /// Encodes a nested array of `Identifiable` objects as references.
    /// Supports `Identifiable` where `ID` is `String`, `UUID`, or `LosslessStringConvertible`.
    /// Falls back to default encoding if the `ID` type is not supported.
    mutating func encode<T: Encodable & Identifiable>(_ identifiables: [T], forKey key: KeyedEncodingContainer<K>.Key) throws {
        guard identifiables.count > 0 else { return }
        // If this encoder does not have a garage, encode as Codable does.
        let encoder = superEncoder()
        guard let garage = encoder.garage else {
            try encodeDefault(identifiables, forKey: key)
            return
        }
        
        // Park the objects and encode them as references.
        // If the ID type is unsupported, fall back to default encoding.
        do {
            try garage.parkAllEncodables(identifiables)
            let references = try identifiables.map { try garage.extractIdentifierString(from: $0) }
            try encode(references, forKey: key)
        } catch GarageError.unsupportedIDConformance {
            try encodeDefault(identifiables, forKey: key)
        }
    }
}

/// These public decoding extensions are exposed to the Swift runtime, to ensure that references to any embedded `Identifiable` objects are correctly retrieved from the top level of the Garage.
/// Supports `Identifiable` where `ID` is `String`, `UUID`, or `LosslessStringConvertible`.
public extension KeyedDecodingContainer {

    private func decodeReferenceIfPresent(forKey key: KeyedDecodingContainer<K>.Key) -> String? {
        let reference: String?
        
        // Swift Codable encodes the identifier directly
        // Objective-C MappableObject encodes a dictionary of identifier and non-anonymous type
        if let identifier = try? decodeIfPresent(String.self, forKey: key) {
            reference = identifier
        } else if let referenceObject = try? decodeIfPresent(__ReferenceObjC.self, forKey: key) {
            reference = referenceObject.id
        } else {
            reference = nil
        }
        
        return reference
    }

    private func decodeReference(forKey key: KeyedDecodingContainer<K>.Key) throws -> String {
        guard let reference = decodeReferenceIfPresent(forKey: key) else {
            let decoder = try superDecoder()
            throw decoder.missingIdentifiableReference()
        }
        
        return reference
    }
    
    private func decodeReferencesIfPresent(forKey key: KeyedDecodingContainer<K>.Key) throws -> [String] {
        let references: [String]
        
        // Swift Codable encodes the array of identifiers directly
        // Objective-C MappableObjects encode an array of dictionaries of identifier and type
        if let identifiers = try? decodeIfPresent([String].self, forKey: key) {
            references = identifiers
        } else if let dictionaries = try? decodeIfPresent([[String:String]].self, forKey: key) {
            references = dictionaries.map { $0[CoreDataObject.Attribute.identifier]! }
        } else {
            references = []
        }
        
        return references
    }
    
    /// Wraps the default `decode` implementation so that we can call it from our Identifiable version.
    private func decodeDefault<T: Decodable>(_ codable: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T {
        return try decode(T.self, forKey: key)
    }

    /// Decodes a reference to a nested `Identifiable` object.
    /// Supports `Identifiable` where `ID` is `String`, `UUID`, or `LosslessStringConvertible`.
    /// Falls back to default decoding if the value was not encoded as a reference.
    func decode<T: Decodable & Identifiable>(_ identifiable: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T {
        // If this decoder does not have a garage, decode as Codable does.
        let decoder = try superDecoder()
        guard let garage = decoder.garage else {
            return try decodeDefault(T.self, forKey: key)
        }
        
        // If the value wasn't encoded as a string reference (e.g., unsupported ID type
        // that was encoded inline), fall back to default decoding.
        guard let reference = decodeReferenceIfPresent(forKey: key) else {
            return try decodeDefault(T.self, forKey: key)
        }
        // If the reference resolves to a parked object, return it.
        if let object = try garage.retrieveDecodable(T.self, identifier: reference) {
            return object
        }
        // The reference didn't resolve. Try default decoding in case the value was
        // encoded inline (e.g., a string-backed enum with unsupported ID type).
        // If default decoding also fails, throw the original reference error.
        do {
            return try decodeDefault(T.self, forKey: key)
        } catch {
            throw decoder.missingIdentifiableReference(typeName: "\(T.self)", identifier: reference)
        }
    }
    
    /// Wraps the default `decodeIfPresent` implementation so that we can call it from our Identifiable version.
    private func decodeIfPresentDefault<T: Decodable>(_ codable: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T? {
        return try decodeIfPresent(T.self, forKey: key)
    }
    
    /// Decodes a reference to a nested `Identifiable` object, if present.
    /// Supports `Identifiable` where `ID` is `String`, `UUID`, or `LosslessStringConvertible`.
    /// Falls back to default decoding if the value was not encoded as a reference.
    func decodeIfPresent<T: Decodable & Identifiable>(_ identifiable: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T? {
        // If this decoder does not have a garage, decode as Codable does.
        let decoder = try superDecoder()
        guard let garage = decoder.garage else {
            return try decodeIfPresentDefault(T.self, forKey: key)
        }
        
        // If the value wasn't encoded as a string reference (e.g., unsupported ID type
        // that was encoded inline), fall back to default decoding.
        guard let reference = decodeReferenceIfPresent(forKey: key) else {
            return try decodeIfPresentDefault(T.self, forKey: key)
        }
        // If the reference resolves, return it. Otherwise, the value may have been
        // encoded inline; try default decoding before returning nil.
        if let object = try garage.retrieveDecodable(T.self, identifier: reference) {
            return object
        }
        return try decodeIfPresentDefault(T.self, forKey: key)
    }
        
    /// Decodes an array of references to nested `Identifiable` objects.
    /// Supports `Identifiable` where `ID` is `String`, `UUID`, or `LosslessStringConvertible`.
    /// Falls back to default decoding if the values were not encoded as references.
    func decode<T: Decodable & Identifiable>(_ identifiable: [T].Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> [T] {
        // If this decoder does not have a garage, decode as Codable does.
        let decoder = try superDecoder()
        guard let garage = decoder.garage else {
            return try decodeIfPresentDefault([T].self, forKey: key) ?? []
        }
        
        let references = try decodeReferencesIfPresent(forKey: key)
        
        // If no string references were found but the key may contain inline-encoded
        // objects (e.g., unsupported ID type), fall back to default decoding.
        if references.isEmpty {
            return try decodeIfPresentDefault([T].self, forKey: key) ?? []
        }
        
        var objects: [T] = []
        for reference in references {
            guard let object = try garage.retrieveDecodable(T.self, identifier: reference) else {
                throw decoder.missingIdentifiableReference(identifier: reference)
            }
            objects.append(object)
        }
        return objects
    }
}
