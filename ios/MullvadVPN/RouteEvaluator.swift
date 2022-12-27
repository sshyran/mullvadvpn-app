//
//  RouteEvaluator.swift
//  MullvadVPN
//
//  Created by Sajad Vishkai on 2022-12-25.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation
import UIKit

protocol RouteEvaluating {
    associatedtype Route

    func evaluate(current: Route?) -> Route
}

typealias AnyRoutable = (any UIViewController & Routable)

protocol Routable: UIViewController, Equatable {
    var route: Route { get }

    init(
        for interface: UIUserInterfaceIdiom,
        with dependencyHandler: DependencyLocator
    )
}

enum Route: Equatable, Hashable {
    case tos
    case login
    case main
    case devices
    case revoked
    case outOfTime

    var routable: any Routable.Type {
        NewViewController.self
//        switch route {
//        case .tos:
//            return TermsOfServiceViewController.self
//        case .login:
//            return LoginViewController.self
//        case .main:
//            return UIViewController()
//        case let .devices(interactor):
//            return DeviceManagementViewController.self
//        case let .revoked(interactor):
//            return RevokedDeviceViewController.self
//        case let .outOfTime(interactor):
//            return OutOfTimeViewController.self
//        }
    }
}

protocol Routing {}

final class AppRouter: Routing {
    var current: Route? {
        (container.topViewController as? AnyRoutable)?.route
    }

    private typealias Condition = (_ current: Route?) -> Bool

    private var pendingRoutes: [PendingRoute] = []

    private struct PendingRoute {
        let route: AnyRoutable
        let condition: Condition
        let navigationType: NavigationType
        let priority: Int

        enum NavigationType {
            case root
            case navigate
            case modal
        }
    }

    private let rootContainer: RootContainerViewController

    private let modalContainer: RootContainerViewController

    private let evaluator = RouteEvaluator {
        (try? SettingsManager.readDeviceState()) ?? .loggedOut
    }

    private let isOnIPad: Bool

    private var userInterfaceIdiom: UIUserInterfaceIdiom

    private lazy var adaptivePresentationController =
        AdaptivePresentationController(rootContainer: rootContainer)

    private var presentedViewController: UIViewController? {
        if isOnIPad {
            return modalContainer.presentingViewController
        }

        return rootContainer.presentingViewController
    }

    private var container: RootContainerViewController {
        isOnIPad ? modalContainer : rootContainer
    }

    init(
        rootContainer: RootContainerViewController,
        modalContainer: RootContainerViewController,
        userInterfaceIdiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) {
        self.rootContainer = rootContainer
        self.modalContainer = modalContainer
        self.userInterfaceIdiom = userInterfaceIdiom

        isOnIPad = userInterfaceIdiom == .pad
    }

    func setRoot(
        to route: AnyRoutable,
        with condition: ((_ current: Route?) -> Bool)? = nil,
        animated: Bool = true,
        _ completionHandler: (() -> Void)?
    ) {
        if let condition = condition {
            if condition(current) {
                _setRoutes([route], animated: animated, completionHandler)
            } else {
                pendingRoutes.append(
                    PendingRoute(
                        route: route,
                        condition: condition,
                        navigationType: .root,
                        priority: .max
                    )
                )
            }
        } else {
            _setRoutes([route], animated: animated, completionHandler)
        }
    }

    func setRoutes(
        _ routes: [AnyRoutable],
        with condition: ((_ current: Route?) -> Bool)? = nil,
        animated: Bool = true,
        _ completionHandler: (() -> Void)?
    ) {
        if let condition = condition {
            if condition(current) {
                _setRoutes(routes, animated: animated, completionHandler)
            } else {
//                pendingRoutes.append(
//                    PendingRoute(route: route, condition: condition, navigationType: .root, priority: .max)
//                )
            }
        } else {
            _setRoutes(routes, animated: animated, completionHandler)
        }
    }

    func navigate(
        to route: AnyRoutable,
        with condition: ((_ current: Route?) -> Bool)? = nil,
        isForced: Bool = false,
        animated: Bool = true
    ) {
        if isForced {
            _navigate(route, animated: animated)
        } else {
            if let condition = condition {
                if condition(current) {
                    _navigate(route, animated: animated)
                } else {
                    pendingRoutes.append(
                        PendingRoute(
                            route: route,
                            condition: condition,
                            navigationType: .navigate,
                            priority: 1
                        )
                    )
                }
            } else {
                _navigate(route, animated: animated)
            }
        }
    }

    func present(
        route: AnyRoutable,
        with condition: ((_ current: Route?) -> Bool)? = nil,
        animated: Bool = true
    ) {
        if let condition = condition {
            if condition(current) {
                _present(route, animated: animated)
            } else {}
        } else {
            _present(route, animated: animated)
        }
    }

    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        if let presentedViewController = presentedViewController {
            presentedViewController.dismiss(animated: animated) {
                completion?()
            }
        } else {
            completion?()
        }
    }

    func popViewController(animated: Bool = true, completion: (() -> Void)? = nil) {
        container.popViewController(animated: animated, completion: completion)
    }

    func popToRootViewController(animated: Bool = true, completion: (() -> Void)? = nil) {
        container.popViewController(animated: animated, completion: completion)
    }

    func present(route: AnyRoutable, after: AnyRoutable) {
        pendingRoutes.append(
            PendingRoute(route: route, condition: { current in
                return current == after.route
            }, navigationType: .modal, priority: 1)
        )
    }

    func navigateTo(route: AnyRoutable, after: AnyRoutable) {
        pendingRoutes.append(
            PendingRoute(route: route, condition: { current in
                return current == after.route
            }, navigationType: .navigate, priority: 1)
        )
    }

    private func checkPendingRoutes() {
        if let index = pendingRoutes
            .sorted(by: { $0.priority > $1.priority })
            .firstIndex(where: { $0.condition(current) })
        {
            let pendingRoute = pendingRoutes[index]

            switch pendingRoute.navigationType {
            case .root:
                break
            case .navigate:
                navigate(to: pendingRoute.route)
            case .modal:
                present(route: pendingRoute.route)
            }
        }
    }

    private func presentModalRootContainerIfNeeded(animated: Bool) {
        modalContainer.preferredContentSize = CGSize(width: 480, height: 600)
        modalContainer.modalPresentationStyle = .formSheet
        modalContainer.presentationController?.delegate = adaptivePresentationController
        modalContainer.isModalInPresentation = true

        if modalContainer.presentingViewController == nil {
            rootContainer.present(modalContainer, animated: animated)
        }
    }

    private func _setRoutes(
        _ routes: [AnyRoutable],
        animated: Bool,
        _ completionHandler: (() -> Void)?
    ) {
        dismiss(animated: animated) { [weak self] in
            self?.container.setViewControllers(
                routes,
                animated: animated,
                completion: completionHandler
            )
        }
    }

    private func _present(_ viewController: AnyRoutable, animated: Bool) {
        dismiss(animated: animated) { [weak self] in
            self?.container.present(viewController, animated: animated)
        }
    }

    private func _navigate(_ route: any Routable, animated: Bool) {
        let checkPendingRoutesClosure: () -> Void = { [weak self] in
            self?.checkPendingRoutes()
        }

        if isOnIPad {
            if modalContainer.isBeingPresented {
                modalContainer.pushViewController(
                    route,
                    animated: animated,
                    completion: checkPendingRoutesClosure
                )
            } else {
                rootContainer.pushViewController(
                    route,
                    animated: animated,
                    completion: checkPendingRoutesClosure
                )
            }
        } else {
            dismiss(animated: animated) { [weak self] in
                self?.rootContainer.pushViewController(
                    route,
                    animated: animated,
                    completion: checkPendingRoutesClosure
                )
            }
        }
    }
}

class NewViewController: UIViewController, Routable {
    required init(for interface: UIUserInterfaceIdiom, with dependencyHandler: DependencyLocator) {
        super.init(nibName: nil, bundle: nil)

        if interface == .pad {
            modalPresentationStyle = .formSheet
            isModalInPresentation = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var route: Route {
        .tos
    }
}

private final class AdaptivePresentationController: NSObject,
    UIAdaptivePresentationControllerDelegate
{
    private let rootContainer: RootContainerViewController

    init(rootContainer: RootContainerViewController) {
        self.rootContainer = rootContainer
    }

    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        if controller.presentedViewController is RootContainerViewController {
            return traitCollection.horizontalSizeClass == .regular ? .formSheet : .fullScreen
        } else {
            return .none
        }
    }

    func presentationController(
        _ presentationController: UIPresentationController,
        willPresentWithAdaptiveStyle style: UIModalPresentationStyle,
        transitionCoordinator: UIViewControllerTransitionCoordinator?
    ) {
        let actualStyle: UIModalPresentationStyle

        // When adaptive presentation is not changing, the `style` is set to `.none`
        if case .none = style {
            actualStyle = presentationController.presentedViewController.modalPresentationStyle
        } else {
            actualStyle = style
        }

        // Force hide header bar in .formSheet presentation and show it in .fullScreen presentation
        if let wrapper = presentationController
            .presentedViewController as? RootContainerViewController
        {
            wrapper.setOverrideHeaderBarHidden(actualStyle == .formSheet, animated: false)
        }

        guard actualStyle == .formSheet else {
            // Move the settings button back into header bar
            rootContainer.removeSettingsButtonFromPresentationContainer()

            return
        }

        // Add settings button into the modal container to make it accessible by user
        if let transitionCoordinator = transitionCoordinator {
            transitionCoordinator.animate { context in
                self.rootContainer.addSettingsButtonToPresentationContainer(context.containerView)
            }
        } else if let containerView = presentationController.containerView {
            rootContainer.addSettingsButtonToPresentationContainer(containerView)
        } else {
//            logger.warning(
//                """
//                Cannot obtain the containerView for presentation controller when presenting with \
//                adaptive style \(actualStyle.rawValue) and missing transition coordinator.
//                """
//            )
        }
    }
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

struct BlockRouteEvaluator: RouteEvaluating {
    var blockHandler: (Route?) -> Route

    func evaluate(current: Route?) -> Route {
        blockHandler(current)
    }
}

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
