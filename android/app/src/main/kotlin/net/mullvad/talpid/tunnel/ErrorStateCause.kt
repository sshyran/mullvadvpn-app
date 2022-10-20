package net.mullvad.talpid.tunnel

import android.os.Parcelable
import java.net.InetAddress
import kotlinx.parcelize.Parcelize
import net.mullvad.mullvadvpn.R

private const val AUTH_FAILED_REASON_EXPIRED_ACCOUNT = "[EXPIRED_ACCOUNT]"

sealed class ErrorStateCause : Parcelable {
    @Parcelize
    class AuthFailed(private val reason: String?) : ErrorStateCause() {
        fun isCausedByExpiredAccount(): Boolean {
            return reason == AUTH_FAILED_REASON_EXPIRED_ACCOUNT
        }
    }

    @Parcelize
    object Ipv6Unavailable : ErrorStateCause()

    @Parcelize
    object SetFirewallPolicyError : ErrorStateCause()

    @Parcelize
    object SetDnsError : ErrorStateCause()

    @Parcelize
    class InvalidDnsServers(val addresses: ArrayList<InetAddress>) : ErrorStateCause()

    @Parcelize
    object StartTunnelError : ErrorStateCause()

    @Parcelize
    class TunnelParameterError(val error: ParameterGenerationError) : ErrorStateCause()

    @Parcelize
    object IsOffline : ErrorStateCause()

    @Parcelize
    object VpnPermissionDenied : ErrorStateCause()

    fun blockingErrorMessageId(): Int {
        return when (this) {
            is InvalidDnsServers -> R.string.invalid_dns_servers
            is AuthFailed -> R.string.auth_failed
            is Ipv6Unavailable -> R.string.ipv6_unavailable
            is SetFirewallPolicyError -> R.string.set_firewall_policy_error
            is SetDnsError -> R.string.set_dns_error
            is StartTunnelError -> R.string.start_tunnel_error
            is IsOffline -> R.string.is_offline
            is TunnelParameterError -> {
                when (error) {
                    ParameterGenerationError.NoMatchingRelay -> R.string.no_matching_relay
                    ParameterGenerationError.NoMatchingBridgeRelay -> {
                        R.string.no_matching_bridge_relay
                    }
                    ParameterGenerationError.NoWireguardKey -> R.string.no_wireguard_key
                    ParameterGenerationError.CustomTunnelHostResultionError -> {
                        R.string.custom_tunnel_host_resolution_error
                    }
                }
            }
            is VpnPermissionDenied -> R.string.vpn_permission_denied_error
        }
    }

    fun notBlockingErrorMessageId(): Int {
        return when (this) {
            is VpnPermissionDenied -> R.string.vpn_permission_denied_error
            else -> R.string.failed_to_block_internet
        }
    }
}
