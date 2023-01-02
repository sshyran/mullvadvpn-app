//
//  RouteEvaluating.swift
//  MullvadVPN
//
//  Created by pronebird on 2023-01-02.
//  Copyright © 2023 Mullvad VPN AB. All rights reserved.
//

import Foundation

protocol RouteEvaluating {
    associatedtype Route

    func evaluate(current: Route?) -> Route
}

struct RouteEvaluator: RouteEvaluating {
    private let getDeviceState: () -> DeviceState

    init(getDeviceState: @escaping () -> DeviceState) {
        self.getDeviceState = getDeviceState
    }

    func evaluate(current: Route?) -> Route {
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
            if let current = current, case .deviceManagement = current {
                return current
            } else {
                return .login
            }

        case .revoked:
            return .revoked
        }
    }
}

struct BlockRouteEvaluator: RouteEvaluating {
    var blockHandler: (Route?) -> Route

    func evaluate(current: Route?) -> Route {
        blockHandler(current)
    }
}
