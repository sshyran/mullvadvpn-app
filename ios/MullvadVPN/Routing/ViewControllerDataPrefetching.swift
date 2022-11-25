//
//  ViewControllerPrefetching.swift
//  MullvadVPN
//
//  Created by pronebird on 25/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

protocol ViewControllerDataPrefetching {
    func fetchData(completion: @escaping (Error?) -> Void)
}
