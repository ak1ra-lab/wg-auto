# general
endpoint="ddns.example.com"
interface="wg0"
interface_ipcidr_prefix="10.0.20"
server_port="51820"
server_IP="${interface_ipcidr_prefix}.1"

# firewall
firewall_zone="${interface}_zone"
firewall_zone_lan="lan"
firewall_zone_wan="wan"
firewall_rule="${interface}_rule"
firewall_forwarding="${interface}_forwarding"
fwmark=$(printf "0x%x" "${server_port}")

# IP CIDR
server_site_ipcidr="10.255.0.0/24"
peer_allowed_ips="${interface_ipcidr_prefix}.0/24, ${server_site_ipcidr}"

# The IP address to start from
peer_IP="2"

# Modify `usernames` with more or less usernames to create any number of peers
#! Linux interface name should no longer than 15 characters
usernames="alpha bravo charl delta"

# Use your device prefix to meet your need
path_prefix="${interface}"
config_dir="${self%/*}/config/${path_prefix}"
peers_dir="${config_dir}/peers"
