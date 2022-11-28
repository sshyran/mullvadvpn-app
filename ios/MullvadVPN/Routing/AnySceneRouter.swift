//
//  AnySceneRouter.swift
//  MullvadVPN
//
//  Created by pronebird on 25/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import UIKit

final class AnySceneRouter<Route: Equatable>: SceneRouter {
    private let presentHandler: (Route, (() -> Void)?) -> Void
    private let viewControllerForRouteHandler: (Route) -> UIViewController?

    init<T>(_ router: T) where T: SceneRouter, T.Route == Route {
        presentHandler = { route, completion in
            router.present(route, completion: completion)
        }
        viewControllerForRouteHandler = { route in
            return router.viewController(for: route)
        }
    }

    func present(_ route: Route, completion: (() -> Void)?) {
        presentHandler(route, completion)
    }
    
    func viewController(for route: Route) -> UIViewController? {
        return viewControllerForRouteHandler(route)
    }
}
