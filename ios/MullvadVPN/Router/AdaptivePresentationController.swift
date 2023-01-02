//
//  AdaptivePresentationController.swift
//  MullvadVPN
//
//  Created by pronebird on 2023-01-02.
//  Copyright © 2023 Mullvad VPN AB. All rights reserved.
//

import Foundation
import UIKit

final class AdaptivePresentationController: NSObject,
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
