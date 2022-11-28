//
//  SceneRouter.swift
//  MullvadVPN
//
//  Created by pronebird on 23/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import UIKit

protocol SceneRouter {
    associatedtype Route: Equatable

    func present(_ route: Route, completion: (() -> Void)?)
    func viewController(for route: Route) -> UIViewController?
}
