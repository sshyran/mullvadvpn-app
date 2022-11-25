//
//  PhoneRouteEvaluator.swift
//  MullvadVPN
//
//  Created by pronebird on 23/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

final class PhoneRouteEvaluator: RouteEvaluator {
    private let getDeviceState: () -> DeviceState

    var current: PhoneRoute?

    init(getDeviceState: @escaping () -> DeviceState) {
        self.getDeviceState = getDeviceState
    }

    func nextAndUpdate() -> PhoneRoute? {
        if let route = next() {
            current = route
            return route
        } else {
            return nil
        }
    }

    func next() -> PhoneRoute? {
        let nextRoute = evaluate()

        if current == nextRoute {
            return nil
        } else {
            return nextRoute
        }
    }

    private func evaluate() -> PhoneRoute {
        guard TermsOfService.isAgreed else {
            return .tos
        }

        switch getDeviceState() {
        case let .loggedIn(accountData, _):
            if accountData.expiry > Date() {
                return .outOfTime
            } else {
                return .main
            }

        case .loggedOut:
            if let current = current, case .devices = current {
                return current
            } else {
                return .login
            }

        case .revoked:
            return .revoked
        }
    }
}
