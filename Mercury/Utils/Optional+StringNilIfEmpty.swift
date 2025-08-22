//
//  Optional+StringNilIfEmpty.swift
//  Mercury
//

import Foundation

extension Optional where Wrapped == String {
    var nilIfEmpty: String? { (self ?? "").isEmpty ? nil : self }
}

