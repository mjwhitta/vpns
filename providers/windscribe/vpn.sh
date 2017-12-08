#!/usr/bin/env bash

default_gateway() {
    unset index
    if [[ -e /home/$SUDO_USER/.config/vpn/windscribe.conf ]]; then
        index="$(
            head -n 1 /home/$SUDO_USER/.config/vpn/windscribe.conf
        )"
    elif [[ -e $HOME/.config/vpn/windscribe.conf ]]; then
        index="$(head -n 1 $HOME/.config/vpn/windscribe.conf)"
    fi
    echo "${index:-50}" # US West
    unset index
}

get_gateway() {
    declare -a gateways
    gateways=($(list_gateways))

    case "$gateway_selection" in
        "random") let "index = $RANDOM % ${#gateways[@]}" ;;
        *) let "index = $(default_gateway)" ;;
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
unset gateway_selection

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

[[ $# -eq 1 ]] || usage 2

if [[ -z $(command -v openvpn) ]]; then
    echo "You need to install openvpn!"
    exit 3
fi

case "$1" in
    "list") ;;
    *)
        if [[ -z $(id | \grep "uid=0(root)") ]]; then
            echo "You need to run as root!"
            exit 4
        fi
        ;;
esac

trap stop_vpn SIGINT

case "$1" in
    "list") list_gateways ;;
    "start") start_vpn ;;
    "stop") stop_vpn ;;
    *) usage 5 ;;
esac
