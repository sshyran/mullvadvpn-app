//
//  ViewControllerFactory.swift
//  MullvadVPN
//
//  Created by pronebird on 23/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import UIKit

protocol ViewControllerFactory {
    associatedtype Route

    func instantiateViewController(for route: Route) -> UIViewController
}
