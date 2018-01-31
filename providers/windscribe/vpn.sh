#!/usr/bin/env bash

default_gateway() {
    local ret
    [[ -z $conf ]] || ret="$(cat $conf | jq -r ".windscribe.gateway")"
    echo "${ret:-51}" # US West
}

get_gateway() {
    declare -a gateways
    gateways=($(list_gateways))

    case "$gateway_selection" in
        "random") let "index = $RANDOM % ${#gateways[@]}" ;;
        *) let "index = $(default_gateway) - 1" ;;
    esac

    echo "${gateways[$index]}"
    unset gateways index
}

list_gateways() {
    find . -iname "*.ovpn" | sed -r "s#./|\.ovpn##g" | sort
}

start_vpn() {
    gateway="$(get_gateway)"
    echo "Using gateway: $gateway"
    echo "If prompted, enter the password."
    openvpn $gateway.ovpn
}

stop_vpn() {
    if [[ -n $(pgrep openvpn) ]]; then
        echo -n "Killing process..."
        kill -9 $(pgrep openvpn)
        sleep 1
        if [[ -n $(command -v ip) ]]; then
            default="$(ip r | awk '/default/ {print $3}')"
            while read route; do
                ip r d $route
            done < <(ip r | tail -n +2 | \grep "via $default")
            unset default route routes
        fi
        echo "done"
    fi
}

usage() {
    echo "Usage: ${0/*\//} [OPTIONS] <action>"
    echo
    echo "Connect to the WindScribe VPN using a set of gateways"
    echo
    echo "Actions:"
    echo "    list             List the gateway options"
    echo "    start            Connect to VPN"
    echo "    stop             Disconnect from VPN"
    echo
    echo "Options:"
    echo "    -h, --help       Display this help message"
    echo "    -r, --random     Use random VPN gateway"
    echo
    exit $1
}

declare -a args
unset conf gateway_selection
if [[ -f /home/$SUDO_USER/.config/vpn/vpn.conf ]]; then
    conf="/home/$SUDO_USER/.config/vpn/vpn.conf"
elif [[ -f $HOME/.config/vpn/vpn.conf ]]; then
    conf="$HOME/.config/vpn/vpn.conf"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        "--") shift && args+=("$@") && break ;;
        "-h"|"--help") usage 0 ;;
        "-r"|"--random") gateway_selection="random" ;;
        *) args+=("$1") ;;
    esac
    shift
done
[[ -z ${args[@]} ]] || set -- "${args[@]}"

[[ $# -eq 1 ]] || usage 1

if [[ -z $(command -v openvpn) ]]; then
    echo "openvpn is not installed"
    exit 2
fi

if [[ $1 != "list" ]] && [[ -z $(id | \grep "uid=0(root)") ]]; then
    echo "You need to run as root!"
    exit 3
fi

trap stop_vpn SIGINT

case "$1" in
    "list") list_gateways ;;
    "start") start_vpn ;;
    "stop") stop_vpn ;;
    *) usage 5 ;;
esac
