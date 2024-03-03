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
	export interface="wg0"
	export interface_ipcidr_prefix="10.0.20"
	export server_port="51820"
	export server_IP="${interface_ipcidr_prefix}.1"
	export firewall_zone="${interface}_zone"
	export firewall_rule="${interface}_rule"
	# `AllowedIPs = 0.0.0.0/0` will route all traffic via WireGuard interface on peers,
	# If this is not what you need, update with your local network IP CIDR
	export server_allowed_ips="0.0.0.0/0"
	# export server_allowed_ips="${interface_ipcidr_prefix}.0/24, 10.255.0.0/24"
	# The IP address to start from
	export peer_IP="2"
	# Use your device prefix to meet your need
	export path_prefix="${interface}"
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

remove_existing_interface() {
	command -v uci >/dev/null || return
	printf "Removing pre-existing WireGuard interface... "
	uci del network.${interface}
	printf "Done\n"
}

remove_existing_peers() {
	command -v uci >/dev/null || return
	printf "Removing pre-existing peers... "
	while uci -q delete network.@wireguard_${interface}[0]; do :; done
	# Keep pre-existing peer keys
	# rm -R "${peers_dir:?}"/*
	printf "Done\n"
}

remove_firewall_zone() {
	command -v uci >/dev/null || return
	printf "Removing pre-existing WireGuard firewall zone... "
	uci del firewall.${firewall_zone}
	printf "Done\n"
}

remove_firewall_rule() {
	command -v uci >/dev/null || return
	printf "Removing pre-existing WireGuard firewall rule... "
	uci del firewall.${firewall_rule}
	printf "Done\n"
}

generate_server_keys() {
	# Generate WireGuard server keys
	printf "Generating WireGuard server keys for '%s' network if not exist... " "${interface}"
	test -f "${config_dir}/${interface}.key" || {
		umask 077
		wg genkey |
			tee "${config_dir}/${interface}.key" |
			wg pubkey >"${config_dir}/${interface}.pub"
	}
	printf "Done\n"
}

create_interface() {
	command -v uci >/dev/null || return
	# Create WireGuard interface
	printf "Creating WireGuard interface for '%s' network... " "${interface}"
	uci set "network.${interface}=interface"
	uci set "network.${interface}.proto=wireguard"
	uci set "network.${interface}.private_key=$(cat "${config_dir}/${interface}.key")"
	uci set "network.${interface}.listen_port=${server_port}"
	uci set "network.${interface}.mtu=1420"
	uci add_list "network.${interface}.addresses=${server_IP}/24"
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

create_firewall_zone() {
	command -v uci >/dev/null || return
	# Create firewall zone
	printf "Create firewall zone for '%s' interface... " "${interface}"
	uci set "firewall.${firewall_zone}=zone"
	uci set "firewall.${firewall_zone}.name=${firewall_zone}"
	uci set "firewall.${firewall_zone}.input=ACCEPT"
	uci set "firewall.${firewall_zone}.output=ACCEPT"
	uci set "firewall.${firewall_zone}.forward=ACCEPT"
	uci set "firewall.${firewall_zone}.masq=1"
	uci add_list "firewall.${firewall_zone}.network=lan"
	uci add_list "firewall.${firewall_zone}.network=${interface}"
	printf "Done\n"
}

add_firewall_rule() {
	command -v uci >/dev/null || return
	# Add firewall rule
	printf "Adding firewall rule for '%s' interface... " "${interface}"
	uci set "firewall.${firewall_rule}=rule"
	uci set "firewall.${firewall_rule}.name=${firewall_rule}"
	uci set "firewall.${firewall_rule}.src=wan"
	uci set "firewall.${firewall_rule}.dest_port=${server_port}"
	uci set "firewall.${firewall_rule}.proto=udp"
	uci set "firewall.${firewall_rule}.target=ACCEPT"
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
			wg pubkey >"${peers_dir}/${peer}/${peer}.pub"
	}
	printf "Done\n"

	# Generate Pre-shared key
	printf "Generating peer PSK for '%s'... " "${peer}"
	test -f "${peers_dir}/${peer}/${peer}.psk" || {
		umask 077
		wg genpsk >"${peers_dir}/${peer}/${peer}.psk"
	}
	printf "Done\n"
}

add_peer_to_server() {
	command -v uci >/dev/null || return
	# Add peer to server
	printf "Adding '%s' to WireGuard '%s' interface... " "${peer}" "${interface}"
	uci set "network.${peer}=wireguard_${interface}"
	uci set "network.${peer}.public_key=$(cat "${peers_dir}/${peer}/${peer}.pub")"
	uci set "network.${peer}.preshared_key=$(cat "${peers_dir}/${peer}/${peer}.psk")"
	uci set "network.${peer}.description=${peer}"
	uci set "network.${peer}.route_allowed_ips=1"
	uci set "network.${peer}.persistent_keepalive=25"
	uci add_list "network.${peer}.allowed_ips=${interface_ipcidr_prefix}.${peer_IP}/32"
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

	remove_existing_interface
	remove_existing_peers
	remove_firewall_zone
	remove_firewall_rule

	generate_server_keys
	create_interface
	create_firewall_zone
	add_firewall_rule
	create_server_config

	loop_peers

	commit_changes
	restart_service
}

main "$@"
