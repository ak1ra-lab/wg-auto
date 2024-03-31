# wg-auto

Automated shell script to set up WireGuard on OpenWRT or generate site-to-site WireGuard config files.

## wg-auto.sh

This script creates 4 peers with usernames 'alpha', 'bravo', 'charlie', and 'delta' on a `lan` network (ref `create_firewall_zone` in `wg-auto.sh`) with WireGuard interface `wg0` by default.

Use `wg-auto.env.sh` as a starting point to make your changes, run with `sh wg-auto.sh wg-auto.local-network.env.sh`.

This script will keep pre-existing peer keys when you re-run this script, if this is not what you need, just delete the peer keys in the `config/${path_prefix}/peers` directory.

## wg-vpc.sh

This script only generates WireGuard config files to set up site-to-site VPN, for example, your local network with AWS VPC.

Use `wg-vpc.env.sh` as a starting point to make your changes, run with `sh wg-vpc.sh wg-vpc.aws-vpc.env.sh`.

## Required Changes

* Update `endpoint` for peers config with your DDNS domain or fixed endpoint,
* Update `server_site_ipcidr` with your server/home network IP CIDR,
    * If you want to route all traffic with WireGuard, modify `peer_allowed_ips=0.0.0.0/0` in `wg-auto.env.sh`, then uncomment the `DNS = ${server_IP}` in `create_peer_config` function.

## Optional Changes

* Modify `usernames` with more or less usernames to create any number of peers
* `path_prefix` is optional, this variable only affects file path for peers config, use your device prefix to meet your need
* The `create_server_config` and `append_peer_to_server_config` functions are used to create equivalent standard server configurations for other purposes, these function does not affect OpenWRT setup.

## Reference

* [[OpenWrt Wiki] WireGuard multi-client server automated](https://openwrt.org/docs/guide-user/services/vpn/wireguard/automated)
