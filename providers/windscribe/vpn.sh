#!/usr/bin/env bash

default_gateway() {
    local ret
    [[ -z $conf ]] || ret="$(cat $conf | jq -cMrS ".$vpn.gateway")"
    [[ $ret != "null" ]] || unset ret
    echo "${ret:-51}" # US West
}

get_gateway() {
    local -a gateways=($(list_gateways))
    local index="0"

    case "$gateway_selection" in
        "random") let "index = $RANDOM % ${#gateways[@]}" ;;
        *) let "index = $(default_gateway) - 1" ;;
    esac

    echo "${gateways[$index]}"
}

list_gateways() {
    find . -iname "*.ovpn" | sed -r "s#./|\.ovpn##g" | sort
}

setup_creds() {
    rm -f creds.txt

    local password
    local username

    if [[ -n $conf ]]; then
        local creds="$(cat $conf | jq -cMrS ".$vpn.credsfile")"
        local cfile="$(
            cat $conf | jq -cMrS ".$vpn.encrypted_credsfile"
        )"
        if [[ $cfile != "null" ]]; then
            gpg -dq $cfile >creds.txt
            chmod 400 creds.txt
            return
        elif [[ $creds != "null" ]]; then
            cp -f $creds creds.txt
            chmod 400 creds.txt
            return
        else
            password="$(cat $conf | jq -cMrS ".$vpn.password")"
            local pfile="$(
                cat $conf | jq -cMrS ".$vpn.encrypted_password"
            )"
            if [[ $pfile != "null" ]]; then
                password="$(gpg -dq $pfile)"
            elif [[ $password == "null" ]]; then
                unset password
            fi
            username="$(cat $conf | jq -cMrS ".$vpn.username")"
            local ufile="$(
                cat $conf | jq -cMrS ".$vpn.encrypted_username"
            )"
            if [[ $ufile != "null" ]]; then
                username="$(gpg -dq $ufile)"
            elif [[ $username == "null" ]]; then
                unset username
            fi
        fi
    fi

    if [[ -z $username ]]; then
        read -p "Enter username: " username
    fi
    if [[ -z $password ]]; then
        read -p "Enter password: " -s password
    fi

    echo "$username" >creds.txt
    echo "$password" >>creds.txt
    chmod 400 creds.txt
}

start_vpn() {
    local gateway="$(get_gateway)"
    echo "Using gateway: $gateway"
    setup_creds
    sudo openvpn $gateway.ovpn
    [[ $? -eq 0 ]] || stop_vpn
}

stop_vpn() {
    echo -n "Killing process and cleaning up..."
    if [[ -n $(pgrep openvpn) ]]; then
        sudo kill -9 $(pgrep openvpn)
        sleep 1
        if [[ -n $(command -v ip) ]]; then
            local default="$(ip r | awk '/default/ {print $3}')"
            while read -r route; do
                sudo ip r d $route
            done < <(ip r | tail -n +2 | \grep "via $default")
            unset route
        fi
    fi
    rm -f creds.txt
    echo "done"
}

usage() {
    echo "Usage: ${0/*\//} [OPTIONS] <action>"
    echo
    echo "Connect to the WindScribe VPN using a set of gateways"
    echo
    echo "Actions:"
    echo "    list            List the gateway options"
    echo "    start           Connect to VPN"
    echo "    stop            Disconnect from VPN"
    echo
    echo "Options:"
    echo "    -h, --help      Display this help message"
    echo "    -r, --random    Use random VPN gateway"
    echo
    exit $1
}

declare -a args
unset conf gateway_selection
if [[ -f $HOME/.config/vpn/vpn.conf ]]; then
    conf="$HOME/.config/vpn/vpn.conf"
fi
vpn="$(basename $(pwd))"

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

if [[ -z $(command -v jq) ]]; then
    echo "jq is not installed"
    exit 3
fi

trap stop_vpn SIGINT

case "$1" in
    "list") list_gateways ;;
    "start") start_vpn ;;
    "stop") stop_vpn ;;
    *) usage 5 ;;
esac
