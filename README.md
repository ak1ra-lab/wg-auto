# wg-auto.sh

Automated shell script to setup WireGuard on OpenWRT

This script creates 4 peers with usernames 'alpha', 'bravo', 'charlie', and 'delta' on a `lan` network with WireGuard interface `wg0` by default. The only changes you need to make are in the `define_variables` function.

This script will keep pre-existing peer keys when you re-run this script, if this is not what your need, just delete the peer keys in `/etc/wireguard/config/${path_prefix}/peers` directory.

## Required Changes

* Update `endpoint` for peers config with your DDNS domain,
* Update `server_allowed_ips`,
    * `AllowedIPs = 0.0.0.0/0` will route all traffic via WireGuard interface on peers,
    * If this is not what you need, update with your local network IP CIDR

## Optional Changes

* Modify `usernames` with more or less usernames to create any number of peers
* `path_prefix` is optional, this variable only affects file path for peers config, use your device prefix to meet your need
* The `create_server_config` and `append_peer_to_server_config` functions are used to create equivalent standard server configurations for other purposes, these function has no effect on OpenWRT setup.

## Reference

* [[OpenWrt Wiki] WireGuard multi-client server automated](https://openwrt.org/docs/guide-user/services/vpn/wireguard/automated)
