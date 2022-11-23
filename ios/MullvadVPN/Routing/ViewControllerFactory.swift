//
//  ViewControllerFactory.swift
//  MullvadVPN
//
//  Created by pronebird on 23/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

protocol ViewControllerFactory {
    func instantiateTOSController() -> TermsOfServiceViewController
    func instantiateLoginController() -> LoginViewController
    func instantiateRevokedController() -> RevokedDeviceViewController
    func instantiateOutOfTimeController() -> OutOfTimeViewController
    func instantiateMainController() -> ConnectViewController
    func instantiateDevicesController(accountNumber: String) -> DeviceManagementViewController
}
