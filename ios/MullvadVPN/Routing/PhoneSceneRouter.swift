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
    let viewControllerFactory: AnyViewControllerFactory<PhoneRoute>

    init<T>(rootContainer: RootContainerViewController, viewControllerFactory: T) where T: ViewControllerFactory, T.Route == PhoneRoute {
        self.rootContainer = rootContainer
        self.viewControllerFactory = AnyViewControllerFactory(viewControllerFactory)
    }

    func present(_ route: PhoneRoute, completion: (() -> Void)?) {
        instantiateAndPrefetchController(for: route) { [weak self] controller, error in
            // TODO: handle error?
            self?.rootContainer.pushViewController(
                controller,
                animated: true,
                completion: completion
            )
        }
    }

    private func instantiateAndPrefetchController(
        for route: PhoneRoute,
        _ completion: @escaping (UIViewController, Error?) -> Void
    ) {
        let controller = viewControllerFactory.instantiateViewController(for: route)

        if let prefetching = controller as? ViewControllerDataPrefetching {
            prefetching.fetchData { error in
                completion(controller, error)
            }
        } else {
            completion(controller, nil)
        }
    }
}
