//
//  SceneRouter.swift
//  MullvadVPN
//
//  Created by pronebird on 23/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

protocol SceneRouter {
    associatedtype Route

    func present(_ route: Route, completion: (() -> Void)?)
}
