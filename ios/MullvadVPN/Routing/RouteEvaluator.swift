//
//  RouteEvaluator.swift
//  MullvadVPN
//
//  Created by pronebird on 25/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

protocol RouteEvaluator: AnyObject {
    associatedtype Route

    var current: Route? { get set }

    func next() -> Route?
    func nextAndUpdate() -> Route?
}
