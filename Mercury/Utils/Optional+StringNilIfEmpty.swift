//
//  Optional+StringNilIfEmpty.swift
//  Mercury
//

import Foundation

extension String {
    var nilIfEmpty: String? { (self).isEmpty ? nil : self }
}

