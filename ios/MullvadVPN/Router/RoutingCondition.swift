//
//  RoutingCondition.swift
//  MullvadVPN
//
//  Created by Sajad Vishkai on 2023-01-02.
//  Copyright © 2023 Mullvad VPN AB. All rights reserved.
//

import Foundation

struct RoutingCondition {
    typealias Condition = (_ current: AppRouter) -> Bool

    var condition: Condition
    var priority: Int?
}
