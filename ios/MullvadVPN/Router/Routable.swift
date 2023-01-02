//
//  Routable.swift
//  MullvadVPN
//
//  Created by Sajad Vishkai on 2023-01-02.
//  Copyright © 2023 Mullvad VPN AB. All rights reserved.
//

import Foundation
import UIKit

typealias AnyRoutable = (any UIViewController & Routable)

protocol Routable: UIViewController, Equatable {
    var route: Route { get }

//    init(
//        for interface: UIUserInterfaceIdiom,
//        with dependencyHandler: RouteDependency
//    )
}
