//
//  SwiftAddress.swift
//  GarageStorageTests
//
//  Created by Brian Arnold on 9/30/19.
//  Copyright © 2019 Wellframe. All rights reserved.
//

// NOTE: No imports

// This is an example of a "simple type" or struct, that is not a reference type, that can still participate in GarageStorage, without needing to be an Identifiable type, a date, or an atomic type (like an integer).
struct SwiftAddress {
    
    var street: String
    var city: String
    var zip: String
    
}

// In order to store this as a property of another object in GarageStorage, it must conform to Codable.
extension SwiftAddress: Codable { }

// In order to store this as a top-level object, it must conform to Identifiable.
extension SwiftAddress: Identifiable {
    // Use a composite key for the identifier.
    var id: String { "\(street)-\(city)-\(zip)" }
}

extension SwiftAddress: Hashable { }
