#!/usr/bin/env bash

default_gateway() {
    local ret
    [[ -z $conf ]] || ret="$(cat $conf | jq -cMrS ".$vpn.gateway")"
    [[ $ret != "null" ]] || unset ret
    echo "${ret:-23}" # us1-udp53
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
            if [[ -f $confdir/$cfile ]]; then
                gpg -dq $confdir/$cfile >creds.txt
                chmod 400 creds.txt
                return
            elif [[ -f $cfile ]]; then
                gpg -dq $cfile >creds.txt
                chmod 400 creds.txt
                return
            else
                echo "$cfile does not exist"
            fi
        elif [[ $creds != "null" ]]; then
            if [[ -f $confdir/$creds ]]; then
                cp -f $confdir/$creds creds.txt
                chmod 400 creds.txt
                return
            elif [[ -f $creds ]]; then
                cp -f $creds creds.txt
                chmod 400 creds.txt
                return
            else
                echo "$creds does not exist"
            fi
        else
            password="$(cat $conf | jq -cMrS ".$vpn.password")"
            local pfile="$(
                cat $conf | jq -cMrS ".$vpn.encrypted_password"
            )"
            if [[ $pfile != "null" ]]; then
                if [[ -f $confdir/$pfile ]]; then
                    password="$(gpg -dq $confdir/$pfile)"
                elif [[ -f $pfile ]]; then
                    password="$(gpg -dq $pfile)"
                else
                    echo "$pfile does not exist"
                fi
            elif [[ $password == "null" ]]; then
                unset password
            fi
            username="$(cat $conf | jq -cMrS ".$vpn.username")"
            local ufile="$(
                cat $conf | jq -cMrS ".$vpn.encrypted_username"
            )"
            if [[ $ufile != "null" ]]; then
                if [[ -f $confdir/$ufile ]]; then
                    username="$(gpg -dq $confdir/$ufile)"
                elif [[ -f $ufile ]]; then
                    username="$(gpg -dq $ufile)"
                else
                    echo "$ufile does not exist"
                fi
            elif [[ $username == "null" ]]; then
                unset username
            fi
        fi
    fi

    [[ -n $username ]] || username="vpnbook"
    [[ -n $password ]] || password="zAmra7WG"

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
    echo "Connect to the VPNBook VPN using a set of gateways"
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
confdir="$HOME/.config/vpn"
if [[ -f $confdir/vpn.conf ]]; then
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

mkdir -p $confdir
case "$1" in
    "list") list_gateways ;;
    "start") start_vpn ;;
    "stop") stop_vpn ;;
    *) usage 5 ;;
esac
