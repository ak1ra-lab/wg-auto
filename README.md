## wg-auto.sh

Automated shell script to set up WireGuard on OpenWRT or Linux.

This script creates 4 peers with usernames 'alpha', 'bravo', 'charlie', and 'delta' on a `lan` network (ref `create_firewall_zone` in `wg-auto.sh`) with WireGuard interface `wg0` by default.

**You can't execute `./wg-auto.sh` without modify `*.env.sh`.** Use `wg-auto.env.sh` as a start point to meets your own need, for example,

```shell
cp wg-auto.env.sh wg-auto.intranet.env.sh

# make your own changes
vim wg-auto.intranet.env.sh

./wg-auto.sh wg-auto.intranet.env.sh
```

## wg-vpc.sh

Automated shell script to set up site-to-site WireGuard on Linux.

This script only generates WireGuard config files to set up site-to-site WireGuard VPN. A typical use is to set up a site-to-site WireGuard VPN between a local intranet and a public cloud VPC.

You need two VM instances located in local intranet and VPC respectively. The VM instances need to have `wireguard` and `wireguard-tools` installed in advance. After generating the configuration, copy the configuration file to the correct location. Use `wg-quick` to pull up the wireguard interface at both ends. After confirming that the connection is correct, use `systemctl` to enable `wg-quick@.service`.

**You can't execute `./wg-vpc.sh` without modify `*.env.sh`.** Use `wg-vpc.env.sh` as a start point to meets your own need, for example,

```shell
cp wg-vpc.env.sh wg-vpc.aws.env.sh

# make your own changes
vim wg-vpc.aws.env.sh

./wg-vpc.sh wg-vpc.aws.env.sh
```

## Default `*.env.sh` config files

Most of the config items in `wg-auto.env.sh` and `wg-vpc.env.sh` have similar meanings. The following are some required and optional config items.

### Required changes

- Update `endpoint` for peers config with your DDNS domain or fixed endpoint,
- Update `server_site_ipcidr` with your server/home network IP CIDR,
  - If you want to route all traffic with WireGuard, modify `peer_allowed_ips=0.0.0.0/0` in `wg-auto.env.sh`, then uncomment the `DNS = ${server_IP}` in `create_peer_config` function.

### Optional changes

- Modify `usernames` with more or less usernames to create any number of peers
  - Linux interface name should no longer than 15 characters
- `path_prefix` is optional, this variable only affects file path for peers config, use your device prefix to meet your need
- The `create_server_config` and `append_peer_to_server_config` functions are used to create equivalent standard server config for other purposes, these function does not affect OpenWRT setup.

This script will keep pre-existing peer keys when you re-run this script, if this is not what you need, just delete the peer keys in the `config/${path_prefix}/peers` directory.

## Reference

- [[OpenWrt Wiki] WireGuard multi-client server automated](https://openwrt.org/docs/guide-user/services/vpn/wireguard/automated)
