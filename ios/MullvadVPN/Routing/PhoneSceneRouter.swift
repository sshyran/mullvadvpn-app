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

    private var breadcrumbs: [PhoneRoute] = []

    init<T>(rootContainer: RootContainerViewController, viewControllerFactory: T) where T: ViewControllerFactory, T.Route == PhoneRoute {
        self.rootContainer = rootContainer
        self.viewControllerFactory = AnyViewControllerFactory(viewControllerFactory)
    }

    func present(_ route: PhoneRoute, completion: (() -> Void)?) {
        instantiateAndPrefetchController(for: route) { [weak self] controller, error in
            guard let self = self else { return }

            self.breadcrumbs.append(route)

            // TODO: handle error?
            self.rootContainer.pushViewController(
                controller,
                animated: true,
                completion: completion
            )
        }
    }

    func viewController(for route: PhoneRoute) -> UIViewController? {
        guard let index = breadcrumbs.firstIndex(of: route) else { return nil }

        let children = rootContainer.viewControllers

        if index < children.count {
            return children[index]
        } else {
            return nil
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
