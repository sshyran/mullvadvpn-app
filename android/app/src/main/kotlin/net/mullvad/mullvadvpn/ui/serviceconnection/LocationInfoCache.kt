package net.mullvad.mullvadvpn.ui.serviceconnection

import kotlin.properties.Delegates.observable
import net.mullvad.mullvadvpn.ipc.Event
import net.mullvad.mullvadvpn.ipc.EventDispatcher
import net.mullvad.core.model.GeoIpLocation

class LocationInfoCache(eventDispatcher: EventDispatcher) {
    private var location: GeoIpLocation? by observable(null) { _, _, newLocation ->
        onNewLocation?.invoke(newLocation)
    }

    var onNewLocation by observable<((GeoIpLocation?) -> Unit)?>(null) { _, _, callback ->
        callback?.invoke(location)
    }

    init {
        eventDispatcher.registerHandler(Event.NewLocation::class) { event ->
            location = event.location
        }
    }

    fun onDestroy() {
        onNewLocation = null
    }
}
