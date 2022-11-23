//
//  PhoneRoute.swift
//  MullvadVPN
//
//  Created by pronebird on 23/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

enum PhoneRoute: Equatable, Hashable {
    case tos
    case login
    case main
    case devices(accountNumber: String)
    case revoked
    case outOfTime
}
