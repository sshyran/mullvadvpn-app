//
//  AnyRouteEvaluator.swift
//  MullvadVPN
//
//  Created by pronebird on 25/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

final class AnyRouteEvaluator<Route>: RouteEvaluator {
    private let getCurrent: () -> Route?
    private let setCurrent: (Route?) -> Void
    private let _next: () -> Route?
    private let _nextAndUpdate: () -> Route?

    init<T>(_ inner: T) where T: RouteEvaluator, T.Route == Route {
        getCurrent = {
            return inner.current
        }
        setCurrent = { newValue in
            inner.current = newValue
        }
        _next = {
            return inner.next()
        }
        _nextAndUpdate = {
            return inner.nextAndUpdate()
        }
    }

    var current: Route? {
        get {
            return getCurrent()
        }
        set {
            setCurrent(newValue)
        }
    }

    func next() -> Route? {
        return _next()
    }

    func nextAndUpdate() -> Route? {
        return _nextAndUpdate()
    }
}
