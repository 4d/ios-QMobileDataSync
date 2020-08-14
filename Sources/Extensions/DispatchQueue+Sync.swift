//
//  DispatchQueue+sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
//

import Foundation

extension DispatchQueue {

    private static var currentKey = 0

    /// The global qos userInteractive
    public static var userInteractive: DispatchQueue { return DispatchQueue.global(qos: .userInteractive) }
    /// The global qos userInitiated
    public static var userInitiated: DispatchQueue { return DispatchQueue.global(qos: .userInitiated) }
    /// The global qos utility
    public static var utility: DispatchQueue { return DispatchQueue.global(qos: .utility) }
    /// The global qos background
    public static var background: DispatchQueue { return DispatchQueue.global(qos: .background) }

    /// Execute `closure` in queue after a delay.
    public func after(_ delay: TimeInterval, execute closure: @escaping () -> Void) {
        asyncAfter(deadline: .now() + delay, execute: closure)
    }

}
