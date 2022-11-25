//
//  AnyViewControllerFactory.swift
//  MullvadVPN
//
//  Created by pronebird on 25/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import UIKit

final class AnyViewControllerFactory<Route>: ViewControllerFactory {
    private let instantiateViewControllerHandler: (Route) -> UIViewController

    init<T>(_ inner: T) where T: ViewControllerFactory, T.Route == Route {
        instantiateViewControllerHandler = { route in
            inner.instantiateViewController(for: route)
        }
    }

    func instantiateViewController(for route: Route) -> UIViewController {
        return instantiateViewControllerHandler(route)
    }
}
