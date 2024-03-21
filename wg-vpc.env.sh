endpoint="ddns.example.com"
interface="wg1"
interface_ipcidr_prefix="10.0.20"
server_port="51820"
server_IP="${interface_ipcidr_prefix}.1"

# The IP address to start from
peer_IP="2"
vpc_site_ipcidr="10.255.0.0/24"
peer_allowed_ips="${interface_ipcidr_prefix}.0/24, ${vpc_site_ipcidr}"

# Modify `usernames` with more or less usernames to create any number of peers
usernames="alpha bravo charlie delta"
# eval "peer_site_ipcidr=\${${username}_site_ipcidr}"
alpha_site_ipcidr="10.255.2.0/24"
bravo_site_ipcidr="10.255.3.0/24"
charlie_site_ipcidr="10.255.4.0/24"
delta_site_ipcidr="10.255.5.0/24"

# Use your device prefix to meet your need
path_prefix="${interface}"
config_dir="${self%/*}/config/${path_prefix}"
peers_dir="${config_dir}/peers"
