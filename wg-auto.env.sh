endpoint="ddns.example.com"
interface="wg0"
interface_ipcidr_prefix="10.0.20"
server_port="51820"
server_IP="${interface_ipcidr_prefix}.1"
firewall_zone="${interface}_zone"
firewall_rule="${interface}_rule"
fwmark=$(printf "0x%x" "${server_port}")

# `AllowedIPs = 0.0.0.0/0` will route all traffic via WireGuard interface on peers,
# If this is not what you need, update with your local network IP CIDR
peer_allowed_ips="0.0.0.0/0"
# peer_allowed_ips="${interface_ipcidr_prefix}.0/24, 10.255.0.0/24"

# The IP address to start from
peer_IP="2"

# Modify `usernames` with more or less usernames to create any number of peers
usernames="alpha bravo charlie delta"

# Use your device prefix to meet your need
path_prefix="${interface}"
config_dir="${self%/*}/config/${path_prefix}"
peers_dir="${config_dir}/peers"
