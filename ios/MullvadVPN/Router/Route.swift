//
//  Route.swift
//  MullvadVPN
//
//  Copyright © 2023 Mullvad VPN AB. All rights reserved.
//

import Foundation

enum Route: Equatable, Hashable {
    case tos
    case login
    case main
    case deviceManagement
    case revoked
    case outOfTime
    case settings
    case selectLocation

    var routable: any Routable.Type {
        switch self {
        case .tos:
            return TermsOfServiceViewController.self
        case .login:
            return LoginViewController.self
        case .main:
            return ConnectViewController.self
        case .deviceManagement:
            return DeviceManagementViewController.self
        case .revoked:
            return RevokedDeviceViewController.self
        case .outOfTime:
            return OutOfTimeViewController.self
        case .settings:
            return SettingsNavigationController.self
        case .selectLocation:
            return SelectLocationNavigationController.self
        }
    }
}
