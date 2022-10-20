package net.mullvad.mullvadvpn.util

import android.content.Context
import net.mullvad.mullvadvpn.R
import net.mullvad.mullvadvpn.ui.extension.getAlwaysOnVpnAppName
import net.mullvad.talpid.tunnel.ErrorState
import net.mullvad.talpid.tunnel.ErrorStateCause
import net.mullvad.talpid.util.addressString

fun ErrorState.getErrorNotificationResources(context: Context): ErrorNotificationMessage {
    return when {
        isBlocking -> ErrorNotificationMessage(
            R.string.blocking_all_connections,
            this.cause.blockingErrorMessageId()
        )
        cause is ErrorStateCause.InvalidDnsServers -> {
            ErrorNotificationMessage(
                R.string.blocking_all_connections,
                this.cause.blockingErrorMessageId(),
                cause.addresses.joinToString { address -> address.addressString() }
            )
        }
        cause is ErrorStateCause.VpnPermissionDenied -> {
            resolveErrorNotificationMessage(context.getAlwaysOnVpnAppName())
        }
        else -> ErrorNotificationMessage(
            R.string.critical_error,
            this.cause.notBlockingErrorMessageId()
        )
    }
}

private fun resolveErrorNotificationMessage(alwaysOnVPN: String?): ErrorNotificationMessage {
    return ErrorNotificationMessage(
        if (alwaysOnVPN != null) {
            R.string.always_on_vpn_error_notification_title
        } else {
            R.string.vpn_permission_error_notification_title
        },
        if (alwaysOnVPN != null) {
            R.string.always_on_vpn_error_notification_content
        } else {
            R.string.vpn_permission_error_notification_message
        },
        alwaysOnVPN
    )
}
