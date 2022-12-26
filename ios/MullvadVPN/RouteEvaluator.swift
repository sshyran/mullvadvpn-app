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

    func evaluate(current: Route?, dependencyHandler: DependencyLocator) -> Route
}

protocol Routable: UIViewController {
    associatedtype Route

    var Route: Route { get }
    static func initialize(for: UIUserInterfaceIdiom) -> UIViewController
}

enum Route: Equatable, Hashable {
    case tos
    case login
    case main
    case devices(interactor: DeviceManagementInteractor)
    case revoked(interactor: RevokedDeviceInteractor)
    case outOfTime(interactor: OutOfTimeInteractor)

    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.tos, .tos),
            (.login, .login),
            (.main, .main),
            (.devices, .devices),
            (.revoked, .revoked),
            (.outOfTime, .outOfTime):
            return true

        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

protocol Routing {

}

final class AppRouter: Routing {
    var current: Route?

    var routes: [any Routable] = []

    private let rootContainer: RootContainerViewController

    private let modalContainer: RootContainerViewController

    private let dependencyHandler: DependencyLocator

    private let evaluator = RouteEvaluator {
        (try? SettingsManager.readDeviceState()) ?? .loggedOut
    }

    private let isOnIPad: Bool

    private var presentedViewController: UIViewController? {
        if isOnIPad {
            return modalContainer.presentingViewController
        }

        return rootContainer.presentingViewController
    }

    init(
        rootContainer: RootContainerViewController,
        modalContainer: RootContainerViewController,
        dependencyHandler: DependencyLocator
    ) {
        self.rootContainer = rootContainer
        self.modalContainer = modalContainer
        self.dependencyHandler = dependencyHandler

        isOnIPad = UIDevice.current.userInterfaceIdiom == .pad
    }
//
//    enum Condition {
//        case constant(Bool)
//        case completion((_ current: Route?) -> Bool)
//    }

    func navigate(
        to route: Route,
        with condition: ((_ current: Route?) -> Bool)? = nil,
        isForced: Bool = false,
        animated: Bool = true
    ) {
        if isForced {
            rootContainer.pushViewController(Self.createViewController(from: route), animated: animated)
        } else {
            if let condition = condition {
                if condition(current) {
                    rootContainer.pushViewController(Self.createViewController(from: route), animated: animated)
                } else {
                    // TODO: register it to be represented when the condition passes.
                }
            } else {
                rootContainer.pushViewController(Self.createViewController(from: route), animated: animated)
            }
        }
    }

    func _navigate() {

    }

    func present(route: Route, animated: Bool = true) {
        if let presentedViewController = presentedViewController {
            presentedViewController.dismiss(animated: animated) { [weak self] in
                self?._present(Self.createViewController(from: route), animated: animated)
            }
        } else {
            _present(Self.createViewController(from: route), animated: animated)
        }
    }

    private func _present(_ view: UIViewController, animated: Bool) {
        if isOnIPad {
            modalContainer.present(view, animated: animated)
        } else {
            rootContainer.present(view, animated: animated)
        }
    }

    private func presentModalRootContainerIfNeeded(animated: Bool) {
        modalContainer.preferredContentSize = CGSize(width: 480, height: 600)
        modalContainer.modalPresentationStyle = .formSheet
//        modalContainer.presentationController?.delegate = self
        modalContainer.isModalInPresentation = true

        if modalContainer.presentingViewController == nil {
            rootContainer.present(modalContainer, animated: animated)
        }
    }

    // TODO: {}
//  push and pop
//  Create route array / registery

    // dismiss all before push

//#error("Make it some one elses reponsibility to create view controllers")
//private func makeTermsOfServiceController(
//    completion: @escaping (UIViewController) -> Void
//) -> TermsOfServiceViewController {
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
//}

    func showAfter(route: Route) {

    }

    func navigateToNext() {
        let deviceState = (try? SettingsManager.readDeviceState()) ?? .loggedOut
        let evaluator = RouteEvaluator(getDeviceState: { deviceState })

        navigate(
            to: evaluator.evaluate(current: current, dependencyHandler: dependencyHandler)
        )
    }

    private static func createViewController(from route: Route) -> UIViewController {
        switch route {
        case .tos:
            return TermsOfServiceViewController()
        case .login:
            return LoginViewController()
        case .main:
            return UIViewController()
        case let .devices(interactor):
            return DeviceManagementViewController(interactor: interactor)
        case let .revoked(interactor):
            return RevokedDeviceViewController(interactor: interactor)
        case let .outOfTime(interactor):
            return OutOfTimeViewController(interactor: interactor)
        }
    }
}

/*
 // MARK: - UIAdaptivePresentationControllerDelegate

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
         logger.warning(
             """
             Cannot obtain the containerView for presentation controller when presenting with \
             adaptive style \(actualStyle.rawValue) and missing transition coordinator.
             """
         )
     }
 }
 */

struct RouteEvaluator: RouteEvaluating {
    private let getDeviceState: () -> DeviceState

    init(getDeviceState: @escaping () -> DeviceState) {
        self.getDeviceState = getDeviceState
    }

    func evaluate(current: Route?, dependencyHandler: DependencyLocator) -> Route {
        guard TermsOfService.isAgreed else {
            return .tos
        }

        lazy var tunnelManager: TunnelManager = dependencyHandler.getService()

        switch getDeviceState() {
        case let .loggedIn(accountData, _):
            if accountData.expiry > Date() {
                return .outOfTime(interactor: OutOfTimeInteractor(storePaymentManager: dependencyHandler.getService(),
                                                    tunnelManager: tunnelManager))
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
            return .revoked(interactor: RevokedDeviceInteractor(tunnelManager: tunnelManager))
        }
    }
}

final class DependencyLocator {
    private var _reg: Dictionary<String, Registry> = [:]

    private var lock = NSLock()

    private var reg: Dictionary<String, Registry> {
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
        var instance: Any? = nil

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
