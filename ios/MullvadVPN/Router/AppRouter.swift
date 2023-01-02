//
//  AppRouter.swift
//  MullvadVPN
//
//  Created by Sajad Vishkai on 2023-01-02.
//  Copyright © 2023 Mullvad VPN AB. All rights reserved.
//

import Foundation
import UIKit

private let navigationDefaultPriority = 0
private let modalDefaultPriority = 1
private let rootDefaultPriority = Int.max

final class AppRouter: Routing {
    var current: AnyRoutable? {
        container.topViewController as? AnyRoutable
    }

    var currentRoute: Route? {
        current?.route
    }

    var routes: [AnyRoutable] {
        container.viewControllers.compactMap { $0 as? AnyRoutable }
    }

    var presentedViewController: UIViewController? {
        if isOnIPad {
            return modalContainer.presentingViewController
        }

        return rootContainer.presentingViewController
    }

    var container: RootContainerViewController {
        isOnIPad ? modalContainer : rootContainer
    }

    typealias Condition = (_ current: AppRouter) -> Bool

    // Private

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

    @inlinable public func contains(where predicate: (AnyRoutable) throws -> Bool) rethrows -> Bool {
        return try routes.contains(where: predicate)
    }

    func removeSettingsButtonFromPresentationContainer() {
        rootContainer.removeSettingsButtonFromPresentationContainer()
    }

    func addSettingsButtonToPresentationContainer(_ presentationContainer: UIView) {
        rootContainer.addSettingsButtonToPresentationContainer(presentationContainer)
    }

    // MARK: - Navigation

    func setRoot(
        to route: AnyRoutable,
        with condition: RoutingCondition? = nil,
        animated: Bool = true,
        _ completionHandler: (() -> Void)?
    ) {
        if let condition = condition {
            if condition.condition(self) {
                _setRoutes([route], animated: animated, completionHandler)
            } else {
                pendingRoutes.append(
                    PendingRoute(
                        route: route,
                        condition: condition.condition,
                        navigationType: .root,
                        priority: condition.priority ?? rootDefaultPriority
                    )
                )
            }
        } else {
            _setRoutes([route], animated: animated, completionHandler)
        }
    }

    func setRoutes(
        _ routes: [AnyRoutable],
        animated: Bool = true,
        _ completionHandler: (() -> Void)? = nil
    ) {
        _setRoutes(routes, animated: animated, completionHandler)
    }

    func navigate(
        to route: AnyRoutable,
        with condition: RoutingCondition? = nil,
        isForced: Bool = false,
        animated: Bool = true
    ) {
        if isForced {
            _navigate(route, animated: animated)
        } else {
            if let condition = condition {
                if condition.condition(self) {
                    _navigate(route, animated: animated)
                } else {
                    pendingRoutes.append(
                        PendingRoute(
                            route: route,
                            condition: condition.condition,
                            navigationType: .navigate,
                            priority: condition.priority ?? navigationDefaultPriority
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
        with condition: RoutingCondition? = nil,
        animated: Bool = true
    ) {
        if let condition = condition {
            if condition.condition(self) {
                _present(route, animated: animated)
            } else {
                pendingRoutes.append(
                    PendingRoute(
                        route: route,
                        condition: condition.condition,
                        navigationType: .modal,
                        priority: condition.priority ?? modalDefaultPriority
                    )
                )
            }
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

    // TODO: {}
    // root condition not satisfy
    // present condition not satisfy
    // add loger
    // Evaluator?

    // #error("Make it some one elses reponsibility to create view controllers")
    // private func makeTermsOfServiceController(
//    completion: @escaping (UIViewController) -> Void
    // ) -> TermsOfServiceViewController {
//    let controller = TermsOfServiceViewController()
//
//    if UIDevice.current.userInterfaceIdiom == .pad {
//        controller.modalPresentationStyle = .formSheet
//        controller.isModalInPresentation = true
//    }
//
//    controller.completionHandler = { controller in
//        TermsOfService.setAgreed()
//        completion(controller)
//    }
//
//    return controller
    // }

//    func setRoot(route: AnyRoutable, condition: @escaping () -> Bool) {
//        pendingRoutes.append(
//            PendingRoute(route: route, condition: { _ in
//                condition()
//            }, navigationType: .root, priority: 1)
//        )
//    }

    func present(route: AnyRoutable, after: AnyRoutable) {
        pendingRoutes.append(
            PendingRoute(route: route, condition: { router in
                return router.currentRoute == after.route
            }, navigationType: .modal, priority: .max)
        )
    }

    func navigateTo(route: AnyRoutable, after: AnyRoutable) {
        pendingRoutes.append(
            PendingRoute(route: route, condition: { router in
                return router.currentRoute == after.route
            }, navigationType: .navigate, priority: .max)
        )
    }

    // MARK: - Private

    private func checkPendingRoutes() {
        if let index = pendingRoutes
            .sorted(by: { $0.priority > $1.priority })
            .firstIndex(where: { $0.condition(self) })
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
            self?.container.present(viewController, animated: animated) { [weak self] in
                self?.checkPendingRoutes()
            }
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
