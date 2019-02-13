//
//  Calendar.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 13/02/2019.
//  Copyright © 2019 Eric Marchand. All rights reserved.
//

import Foundation

extension Calendar {
    static let utc: Calendar  = {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")! // swiftlint:disable:this superfluous_disable_command force_cast
        return calendar
    }()
    static let localTime: Calendar  = {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar
    }()
}
