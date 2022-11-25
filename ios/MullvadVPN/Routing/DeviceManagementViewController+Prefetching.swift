//
//  DeviceManagementViewController+Prefetching.swift
//  MullvadVPN
//
//  Created by pronebird on 25/11/2022.
//  Copyright © 2022 Mullvad VPN AB. All rights reserved.
//

import Foundation

extension DeviceManagementViewController: ViewControllerDataPrefetching {
    func fetchData(completion: @escaping (Error?) -> Void) {
        fetchDevices(animateUpdates: false) { operationCompletion in
            completion(Result { try operationCompletion.get() }.error)
        }
    }
}
