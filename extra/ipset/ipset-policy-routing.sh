#!/bin/bash
# author: ak1ra
# date: 2025-03-11
# 使用 ipset 为特定 IP ranges 配置策略路由

umask 077

require_command() {
    for c in "$@"; do
        command -v "$c" >/dev/null || {
            echo >&2 "required command '$c' is not installed, aborting..."
            exit 1
        }
    done
}

fetch_gcloud_ipv4() {
    echo "Fetch Google Cloud IP ranges..."
    curl -s "${GCLOUD_URL}" | jq -r --arg GCLOUD_REGION_REGEX "${GCLOUD_REGION_REGEX}" \
        '.prefixes[] | select(.scope | test($GCLOUD_REGION_REGEX)) | (.ipv4Prefix // empty)' >"${GCLOUD_IP_FILE}"
}

fetch_aws_ipv4() {
    echo "Fetch AWS IP ranges..."
    curl -s "${AWS_URL}" | jq -r --arg AWS_REGION_REGEX "${AWS_REGION_REGEX}" \
        '.prefixes[] | select(.region | test($AWS_REGION_REGEX)) | (.ip_prefix // empty)' >"${AWS_IP_FILE}"
}

create_ipset() {
    local IPSET="$1"
    local IP_FILE="$2"
    ipset create "${IPSET}" hash:net family inet
    while IFS= read -r ip; do
        ipset -q add "${IPSET}" "${ip}"
    done <"${IP_FILE}"
}

update_ipset() {
    local IPSET="$1"
    local IP_FILE="$2"
    if ipset -q -t list "${IPSET}" >/dev/null 2>&1; then
        echo "Update ipset..."
        IPSET_NAME_TMP="${IPSET}_${RANDOM}"
        create_ipset "${IPSET_NAME_TMP}" "${IP_FILE}"

        ipset swap "${IPSET}" "${IPSET_NAME_TMP}"
        ipset destroy "${IPSET_NAME_TMP}"
    else
        echo "Create ipset..."
        create_ipset "${IPSET}" "${IP_FILE}"
    fi
}

setup_iptables() {
    local IPSET="$1"
    echo "Set iptables..."
    if ! iptables -t mangle -C OUTPUT -m set --match-set "${IPSET}" dst -m comment --comment "${ROUTING_TABLE_NAME}" -j MARK --set-mark "${FWMARK}" 2>/dev/null; then
        iptables -t mangle -A OUTPUT -m set --match-set "${IPSET}" dst -m comment --comment "${ROUTING_TABLE_NAME}" -j MARK --set-mark "${FWMARK}"
    fi
}

configure_routing_table() {
    if ! grep -qE "^${ROUTING_TABLE_ID} ${ROUTING_TABLE_NAME}" "${RT_TABLES}"; then
        echo "Add route table ${ROUTING_TABLE_NAME} with ID ${ROUTING_TABLE_ID} ..."
        echo "${ROUTING_TABLE_ID} ${ROUTING_TABLE_NAME}" | tee "${RT_TABLES}"
    fi
}

add_routes() {
    echo "Add IP rule and routes..."
    ip rule add from all fwmark "${FWMARK}" lookup "${ROUTING_TABLE_NAME}"
    ip route add default via "${GATEWAY}" table "${ROUTING_TABLE_NAME}"
}

persist_ipset() {
    # ipset-persistent
    # 看了下 ipset-persistent 附带的 /usr/share/netfilter-persistent/plugins.d/10-ipset 脚本
    # 才发现 ipsets 的持久化配置文件是 /etc/iptables/ipsets, 为什么放 /etc/iptables 目录下呢? 真够怪的...
    echo "Persistent ipset..."
    ipset save >/etc/iptables/ipsets
}

persist_iptables() {
    # iptables-persistent
    # /usr/share/netfilter-persistent/plugins.d/15-ip4tables
    echo "Persistent iptables rules..."
    iptables-save | grep -vE 'wg[0-9]+' >/etc/iptables/rules.v4
}

persist_netplan_routes() {
    if ! command -v netplan &>/dev/null; then
        return
    fi
    echo "Persistent IP rule and IP routes using netplan..."
    cat <<EOF >"${NETPLAN_YAML}"
# ${NETPLAN_YAML}
network:
  version: 2
  ethernets:
    $(ip route get ${GATEWAY} | awk 'NR==1 {print $3}'):
      routes:
        - to: default
          via: ${GATEWAY}
          table: ${ROUTING_TABLE_ID}
      routing-policy:
        - from: 0.0.0.0/0
          mark: $(printf "%d" "${FWMARK}")
          table: ${ROUTING_TABLE_ID}
EOF
    netplan try
}

main() {
    if [ "${EUID}" -ne 0 ]; then
        echo "Please run this script with root user."
        exit 1
    fi

    # Environments
    GCLOUD_URL="https://www.gstatic.com/ipranges/cloud.json"
    GCLOUD_REGION_REGEX="^(asia-southeast1|us-(west|central|east)1|europe-west1)"
    GCLOUD_IPSET="gcloud_ipv4"
    GCLOUD_IP_FILE="/tmp/${GCLOUD_IPSET}.txt"

    AWS_URL="https://ip-ranges.amazonaws.com/ip-ranges.json"
    AWS_REGION_REGEX="^(ap-southeast-1|us-(west|east)-[12]|GLOBAL)"
    AWS_IPSET="aws_ipv4"
    AWS_IP_FILE="/tmp/${AWS_IPSET}.txt"

    GATEWAY="10.16.32.1"
    ROUTING_TABLE_ID="232"
    ROUTING_TABLE_NAME="dedicated_proxy"
    FWMARK="$(printf "0x%x" "${ROUTING_TABLE_ID}")"

    RT_TABLES="/etc/iproute2/rt_tables.d/${ROUTING_TABLE_NAME}.conf"
    NETPLAN_YAML="/etc/netplan/99-${ROUTING_TABLE_NAME}.yaml"

    apt-get install -y jq iproute2 ipset ipset-persistent iptables iptables-persistent
    require_command ip ipset iptables jq netplan

    fetch_gcloud_ipv4
    update_ipset "${GCLOUD_IPSET}" "${GCLOUD_IP_FILE}"
    setup_iptables "${GCLOUD_IPSET}"

    fetch_aws_ipv4
    update_ipset "${AWS_IPSET}" "${AWS_IP_FILE}"
    setup_iptables "${AWS_IPSET}"

    configure_routing_table
    # add_routes

    persist_ipset
    persist_iptables
    persist_netplan_routes

    echo "Done!"
}

main "$@"
