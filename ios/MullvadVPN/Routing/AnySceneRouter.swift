//
//  AnySceneRouter.swift
//  MullvadVPN
//
//  Created by pronebird on 25/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

final class AnySceneRouter<Route>: SceneRouter {
    private let presentHandler: (Route, (() -> Void)?) -> Void

    init<T>(_ router: T) where T: SceneRouter, T.Route == Route {
        presentHandler = { route, completion in
            router.present(route, completion: completion)
        }
    }

    func present(_ route: Route, completion: (() -> Void)?) {
        presentHandler(route, completion)
    }
}
