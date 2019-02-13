//
//  Date.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 13/02/2019.
//  Copyright © 2019 Eric Marchand. All rights reserved.
//

import Foundation

extension Date {
    public var isUTCStartOfDay: Bool {
        return Calendar.utc.startOfDay(for: self) == self
    }
}
