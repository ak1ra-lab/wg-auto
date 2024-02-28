#!/bin/ash
# shellcheck shell=dash
# https://openwrt.org/docs/guide-user/services/vpn/wireguard/automated

require_command() {
	for c in "$@"; do
		command -v "$c" >/dev/null || {
			echo >&2 "required command '$c' is not installed, aborting..."
			exit 1
		}
	done
}

splash_screen() {
	command -v uci >/dev/null || return
	cat <<-EOF
		======================================
		|      Automated shell script        |
		|   to setup WireGuard on OpenWRT    |
		======================================
	EOF
}

define_variables() {
	# Define Variables
	printf "Defining variables... "
	export endpoint="my-ddns.example.com"
	export interface="wg_lan"
	export interface_ipcidr_prefix="10.0.16"
	export server_port="51816"
	export server_firewall_zone="lan"
	export server_IP="${interface_ipcidr_prefix}.1"
	# `AllowedIPs = 0.0.0.0/0` will route all traffic via WireGuard interface on peers,
	# If this is not what you need, update with your local network IP CIDR
	export server_allowed_ips="0.0.0.0/0"
	# export server_allowed_ips="${interface_ipcidr_prefix}.0/24, 10.255.0.0/24"
	# The IP address to start from
	export peer_IP="2"
	# Use your device prefix to meet your need
	export path_prefix="ax6s_${interface}"
	export config_dir="/etc/wireguard/config/${path_prefix}"
	export peers_dir="${config_dir}/peers"
	# Modify `usernames` with more or less usernames to create any number of peers
	export usernames="alpha bravo charlie delta"
	printf "Done\n"
}

create_dirs() {
	# Create directories
	printf "Creating directories and pre-defining permissions on those directories... "
	mkdir -p ${peers_dir}
	printf "Done\n"
}

rename_firewall_zone() {
	command -v uci >/dev/null || return
	printf "Rename firewall.@zone[0] to lan and firewall.@zone[1] to wan... "
	uci rename firewall.@zone[0]="lan"
	uci rename firewall.@zone[1]="wan"
	printf "Done\n"
}

remove_existing_interface() {
	command -v uci >/dev/null || return
	# Remove pre-existing WireGuard interface
	printf "Removing pre-existing WireGuard interface... "
	uci del_list firewall.${server_firewall_zone}.network="${interface}"
	uci del network.${interface}
	printf "Done\n"
}

remove_existing_peers() {
	command -v uci >/dev/null || return
	# Remove existing peers
	printf "Removing pre-existing peers... "
	while uci -q delete network.@wireguard_${interface}[0]; do :; done
	# Keep pre-existing peer keys
	# rm -R "${peers_dir:?}"/*
	printf "Done\n"
}

remove_firewall_rule() {
	command -v uci >/dev/null || return
	# Remove pre-existing WireGuard firewall rules
	printf "Removing pre-existing WireGuard firewall rules... "
	uci del firewall.${interface}
	printf "Done\n"
}

generate_server_keys() {
	# Generate WireGuard server keys
	printf "Generating WireGuard server keys for '%s' network if not exist... " "${interface}"
	test -f "${config_dir}/${interface}.key" || {
		umask 077
		wg genkey |
			tee "${config_dir}/${interface}.key" |
			wg pubkey |
			tee "${config_dir}/${interface}.pub"
	}
	printf "Done\n"
}

create_interface() {
	command -v uci >/dev/null || return
	# Create WireGuard interface for 'interface' network
	printf "Creating WireGuard interface for '%s' network... " "${interface}"
	uci set network.${interface}=interface
	uci set network.${interface}.proto='wireguard'
	uci set network.${interface}.private_key="$(cat ${config_dir}/${interface}.key)"
	uci set network.${interface}.listen_port="${server_port}"
	uci set network.${interface}.mtu='1420'
	uci add_list network.${interface}.addresses="${server_IP}/24"

	# Add '${interface}' to '${server_firewall_zone}' firewall zone
	uci add_list firewall.${server_firewall_zone}.network="${interface}"
	printf "Done\n"
}

create_server_config() {
	# Create equivalent standard server configuration
	printf "Creating server config for '%s'... " "${interface}"
	# Make your changes here to meet your requirements
	lan_interface="eth0"
	wan_interface="eth1"
	cat <<-EOF >"${config_dir}/${interface}.conf"
		[Interface]
		Address = ${server_IP}/24
		ListenPort = ${server_port}
		PrivateKey = $(cat "${config_dir}/${interface}.key") # server's private key

		PostUp = iptables -A FORWARD -i %i -j ACCEPT
		# outbound packets via lan interface
		PostUp = iptables -t nat -A POSTROUTING -o ${lan_interface} -j MASQUERADE
		# outbound packets via wan interface
		PostUp = iptables -t nat -A POSTROUTING -o ${wan_interface} -j MASQUERADE

		PreDown = iptables -D FORWARD -i %i -j ACCEPT
		PreDown = iptables -t nat -D POSTROUTING -o ${lan_interface} -j MASQUERADE
		PreDown = iptables -t nat -D POSTROUTING -o ${wan_interface} -j MASQUERADE

	EOF
	printf "Done\n"
}

add_firewall_rule() {
	command -v uci >/dev/null || return
	# Add firewall rule
	printf "Adding firewall rule for '%s' network... " "${interface}"
	uci set firewall.${interface}="rule"
	uci set firewall.${interface}.name="Allow-WireGuard-${interface}"
	uci set firewall.${interface}.src="wan"
	uci set firewall.${interface}.dest_port="${server_port}"
	uci set firewall.${interface}.proto="udp"
	uci set firewall.${interface}.target="ACCEPT"
	printf "Done\n"
}

generate_peer_keys() {
	printf "\n"
	# Create directory for storing peers
	peer="${path_prefix}_${username}"
	printf "Creating directory for peer '%s'... " "${peer}"
	mkdir -p "${peers_dir}/${peer}"
	printf "Done\n"

	# Generate peer keys
	printf "Generating peer keys for '%s' if not exist... " "${peer}"
	test -f "${peers_dir}/${peer}/${peer}.key" || {
		umask 077
		wg genkey |
			tee "${peers_dir}/${peer}/${peer}.key" |
			wg pubkey |
			tee "${peers_dir}/${peer}/${peer}.pub"
	}
	printf "Done\n"

	# Generate Pre-shared key
	printf "Generating peer PSK for '%s'... " "${peer}"
	test -f "${peers_dir}/${peer}/${peer}.psk" || {
		umask 077
		wg genpsk |
			tee "${peers_dir}/${peer}/${peer}.psk"
	}
	printf "Done\n"
}

add_peer_to_server() {
	command -v uci >/dev/null || return
	# Add peer to server
	printf "Adding '%s' to WireGuard server... " "${peer}"
	uci add network wireguard_${interface}
	uci set network.@wireguard_${interface}[-1].public_key="$(cat "${peers_dir}/${peer}/${peer}.pub")"
	uci set network.@wireguard_${interface}[-1].preshared_key="$(cat "${peers_dir}/${peer}/${peer}.psk")"
	uci set network.@wireguard_${interface}[-1].description="${peer}"
	uci add_list network.@wireguard_${interface}[-1].allowed_ips="${interface_ipcidr_prefix}.${peer_IP}/32"
	uci set network.@wireguard_${interface}[-1].route_allowed_ips='1'
	uci set network.@wireguard_${interface}[-1].persistent_keepalive='25'
	printf "Done\n"
}

create_peer_config() {
	# Create peer configuration
	printf "Creating config for '%s'... " "${peer}"
	cat <<-EOF >"${peers_dir}/${peer}/${peer}.conf"
		[Interface]
		Address = ${interface_ipcidr_prefix}.${peer_IP}/32
		PrivateKey = $(cat "${peers_dir}/${peer}/${peer}.key") # peer's private key
		DNS = ${server_IP}

		[Peer]
		PublicKey = $(cat "${config_dir}/${interface}.pub") # server's public key
		PresharedKey = $(cat "${peers_dir}/${peer}/${peer}.psk") # peer's pre-shared key
		PersistentKeepalive = 25
		AllowedIPs = ${server_allowed_ips}
		Endpoint = ${endpoint}:${server_port}
	EOF
	printf "Done\n"
}

append_peer_to_server_config() {
	# Append peer to server configuration
	printf "Append '%s' config to '%s'... " "${peer}" "${interface}"
	cat <<-EOF >>"${config_dir}/${interface}.conf"
		[Peer] # ${peer}
		PublicKey = $(cat "${peers_dir}/${peer}/${peer}.pub") # peer's public key
		PresharedKey = $(cat "${peers_dir}/${peer}/${peer}.psk") # peer's pre-shared key
		PersistentKeepalive = 25
		AllowedIPs = ${interface_ipcidr_prefix}.${peer_IP}/32

	EOF
	printf "Done\n"
}

loop_peers() {
	for username in ${usernames}; do
		generate_peer_keys
		add_peer_to_server
		create_peer_config
		append_peer_to_server_config

		peer_IP=$((peer_IP + 1))
	done
}

commit_changes() {
	command -v uci >/dev/null || return
	# Commit UCI changes
	printf "\nCommiting changes... "
	uci commit
	printf "Done\n"
}

restart_service() {
	command -v uci >/dev/null || return
	# Restart WireGuard interface
	printf "\nRestarting WireGuard interface... "
	ifup ${interface}
	printf "Done\n"

	# Restart firewall
	printf "\nRestarting firewall... "
	/etc/init.d/firewall restart
	printf "Done\n"
}

main() {
	require_command wg

	umask 077
	splash_screen

	define_variables
	create_dirs
	rename_firewall_zone

	remove_existing_interface
	remove_existing_peers
	remove_firewall_rule

	generate_server_keys
	create_interface
	add_firewall_rule
	create_server_config

	loop_peers

	commit_changes
	restart_service
}

main "$@"
