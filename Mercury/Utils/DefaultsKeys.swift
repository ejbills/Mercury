//
//  DefaultsKeys.swift
//  Mercury
//
//  Created by Ethan Bills on 8/14/25.
//

import Foundation
import Defaults

extension Defaults.Keys {
    static let clientId = Key<String>("clientId", default: "")
    static let accessToken = Key<String?>("accessToken")
    static let refreshToken = Key<String?>("refreshToken")
    static let accessTokenExpiry = Key<Date?>("accessTokenExpiry")
    static let userInfo = Key<RedditUser?>("userInfo")
    static let isSetupComplete = Key<Bool>("isSetupComplete", default: false)
    static let lastLoginDate = Key<Date?>("lastLoginDate")
    static let compactMode = Key<Bool>("compactMode", default: false)
}
