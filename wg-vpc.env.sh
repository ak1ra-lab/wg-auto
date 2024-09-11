# shellcheck shell=dash
endpoint="ddns.example.com"
interface="wg1"
interface_ipcidr_prefix="10.0.20"
server_port="51820"
server_IP="${interface_ipcidr_prefix}.1"

# The IP address to start from
peer_IP="2"
vpc_site_ipcidr="10.255.0.0/24"
peer_allowed_ips="${interface_ipcidr_prefix}.0/24, ${vpc_site_ipcidr}"
# https://cloud.google.com/vpc/docs/mtu
# https://gist.github.com/nitred/f16850ca48c48c79bf422e90ee5b9d95
peer_mtu=1380

# Modify `usernames` with more or less usernames to create any number of peers
usernames="alpha bravo charlie delta"
# eval "peer_site_ipcidr=\${${username}_site_ipcidr}"
# https://www.shellcheck.net/wiki/SC2034
export alpha_site_ipcidr="10.255.2.0/24"
export bravo_site_ipcidr="10.255.3.0/24"
export charlie_site_ipcidr="10.255.4.0/24"
export delta_site_ipcidr="10.255.5.0/24"

# Use your device prefix to meet your need
path_prefix="${interface}"
config_dir="${self%/*}/config/${path_prefix}"
peers_dir="${config_dir}/peers"
