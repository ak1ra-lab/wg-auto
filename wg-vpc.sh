#!/bin/ash
# shellcheck shell=dash source=wg-vpc.env.sh

require_command() {
	for c in "$@"; do
		command -v "$c" >/dev/null || {
			echo >&2 "required command '$c' is not installed, aborting..."
			exit 1
		}
	done
}

splash_screen() {
	cat <<-EOF
		======================================
		|      Automated shell script        |
		|   to setup site to site WireGuard  |
		======================================
	EOF
}

create_dirs() {
	# Create directories
	printf "Creating directories and pre-defining permissions on those directories... "
	mkdir -p "${peers_dir}"
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

create_server_config() {
	# Create equivalent standard server configuration
	printf "Creating server config for '%s'... " "${interface}"
	cat <<-EOF >"${config_dir}/${interface}.conf"
		[Interface]
		Address = ${server_IP}/24
		ListenPort = ${server_port}
		PrivateKey = $(cat "${config_dir}/${interface}.key") # server's private key

		PostUp = iptables -t mangle -A FORWARD -i %i -p tcp --tcp-flags SYN,RST SYN -m comment --comment "%i" -j TCPMSS --clamp-mss-to-pmtu
		PostDown = iptables -t mangle -D FORWARD -i %i -p tcp --tcp-flags SYN,RST SYN -m comment --comment "%i" -j TCPMSS --clamp-mss-to-pmtu

	EOF
	printf "Done\n"
}

append_peer_to_server_config() {
	# Append peer to server configuration
	printf "Append '%s' config to '%s'... " "${peer}" "${interface}"
	eval "peer_site_ipcidr=\${${username}_site_ipcidr}"
	# shellcheck disable=SC2154
	cat <<-EOF >>"${config_dir}/${interface}.conf"
		[Peer] # ${peer}
		PublicKey = $(cat "${peers_dir}/${peer}/${peer}.pub") # peer's public key
		PresharedKey = $(cat "${peers_dir}/${peer}/${peer}.psk") # peer's pre-shared key
		PersistentKeepalive = 25
		AllowedIPs = ${interface_ipcidr_prefix}.${peer_IP}/32, ${peer_site_ipcidr}

	EOF
	printf "Done\n"
}

create_peer_config() {
	# Create peer configuration
	printf "Creating config for '%s'... " "${peer}"
	cat <<-EOF >"${peers_dir}/${peer}/${peer}.conf"
		[Interface]
		Address = ${interface_ipcidr_prefix}.${peer_IP}/32
		PrivateKey = $(cat "${peers_dir}/${peer}/${peer}.key") # peer's private key
		MTU = ${peer_mtu}

		[Peer]
		PublicKey = $(cat "${config_dir}/${interface}.pub") # server's public key
		PresharedKey = $(cat "${peers_dir}/${peer}/${peer}.psk") # peer's pre-shared key
		PersistentKeepalive = 25
		AllowedIPs = ${peer_allowed_ips}
		Endpoint = ${endpoint}:${server_port}
	EOF
	printf "Done\n"
}

loop_peers() {
	for username in ${usernames}; do
		generate_peer_keys
		append_peer_to_server_config
		create_peer_config

		peer_IP=$((peer_IP + 1))
	done
}

main() {
	require_command wg

	self="$(readlink -f "$0")"
	config_file_default="${self%.sh}.env.sh"

	config_file="$1"
	test -f "${config_file}" || config_file="${config_file_default}"
	config_file="$(readlink -f "${config_file}")"
	. "${config_file}"

	umask 077
	splash_screen

	create_dirs

	generate_server_keys
	create_server_config

	loop_peers
}

main "$@"
