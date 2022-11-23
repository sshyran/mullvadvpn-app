//
//  PhoneSceneRouter.swift
//  MullvadVPN
//
//  Created by pronebird on 23/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import UIKit

final class PhoneSceneRouter: SceneRouter {
    let rootContainer: RootContainerViewController
    let viewControllerFactory: ViewControllerFactory

    init(rootContainer: RootContainerViewController, viewControllerFactory: ViewControllerFactory) {
        self.rootContainer = rootContainer
        self.viewControllerFactory = viewControllerFactory
    }

    func present(_ route: PhoneRoute, completion: (() -> Void)?) {
        makeAndSetupViewController(for: route) { [weak self] controller, error in
            self?.rootContainer.pushViewController(
                controller,
                animated: true,
                completion: completion
            )
        }
    }

    private func makeAndSetupViewController(
        for route: PhoneRoute,
        _ completion: @escaping (UIViewController, Error?) -> Void
    ) {
        switch route {
        case .tos:
            completion(viewControllerFactory.instantiateTOSController(), nil)

        case .login:
            completion(viewControllerFactory.instantiateLoginController(), nil)

        case let .devices(accountNumber):
            let controller = viewControllerFactory
                .instantiateDevicesController(accountNumber: accountNumber)

            controller.fetchDevices(animateUpdates: false) { operationCompletion in
                completion(controller, operationCompletion.error)
            }

        case .main:
            completion(viewControllerFactory.instantiateMainController(), nil)

        case .revoked:
            completion(viewControllerFactory.instantiateRevokedController(), nil)

        case .outOfTime:
            completion(viewControllerFactory.instantiateOutOfTimeController(), nil)
        }
    }
}
