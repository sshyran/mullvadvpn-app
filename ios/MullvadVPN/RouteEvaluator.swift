//
//  RouteEvaluator.swift
//  MullvadVPN
//
//  Created by Sajad Vishkai on 2022-12-25.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation
import UIKit

final class DependencyLocator {
    private var _reg: [String: Registry] = [:]

    private var lock = NSLock()

    private var reg: [String: Registry] {
        set {
            lock.lock()
            defer {
                lock.unlock()
            }

            _reg = newValue
        }

        get {
            lock.lock()
            defer {
                lock.unlock()
            }

            return _reg
        }
    }

    private enum Registry {
        case instance(Any)
        case recipe(() -> Any)

        func unwrap() -> Any {
            switch self {
            case let .instance(instance):
                return instance
            case let .recipe(recipe):
                return recipe
            }
        }
    }

    private static func typeName(of some: Any) -> String {
        return String(describing: some)
    }

    func isExists(key: String) -> Bool {
        reg[key] != nil
    }

    func addService<T>(recipe: @escaping () -> T) {
        let key = Self.typeName(of: T.self)

        guard !isExists(key: key) else { return }
        reg[key] = .recipe(recipe)
    }

    func addService<T>(instance: T) {
        let key = Self.typeName(of: T.self)

        guard !isExists(key: key) else { return }
        reg[key] = .instance(instance)
    }

    func getService<T>(shouldRemoveService: Bool = false) -> T {
        let key = Self.typeName(of: T.self)
        var instance: Any?

        if let service = reg[key] {
            instance = service.unwrap()

            // Replace the recipe with the produced instance if this is the case.
            if case let .recipe(closure) = service {
                instance = closure()

                reg[key] = nil
                addService(instance: instance)
            }

            if shouldRemoveService {
                removeService(recipe: key)
            }
        }

        if let service = instance as? T {
            return service
        }

        preconditionFailure("Accessing a service that does not exists.")
    }

    func removeService(recipe: String) {
        reg[recipe] = nil
    }

    func removeService<T>(type: T) {
        reg[Self.typeName(of: T.self)] = nil
    }
}
