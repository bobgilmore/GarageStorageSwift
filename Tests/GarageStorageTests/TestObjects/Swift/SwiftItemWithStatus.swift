//
//  SwiftItemWithStatus.swift
//  GarageStorageTests
//
//  Created on 3/5/26.
//

import Foundation

/// An enum conforming to Codable and Identifiable where ID is Self.
/// This means the ID type does not conform to String, LosslessStringConvertible, or UUID.
enum SwiftStatus: String, Codable, Identifiable {
    case active
    case inactive
    case pending

    var id: Self { self }
}

/// A top-level object that references a SwiftStatus enum property.
/// Used to test the bug where encoding a referenced Identifiable whose ID
/// is not String/LosslessStringConvertible/UUID fails to fall back to encodeDefault.
struct SwiftItemWithStatus: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var status: SwiftStatus
}
