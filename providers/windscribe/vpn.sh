#!/usr/bin/env bash

err() { echo -e "${color:+\e[31m}[!] $@\e[0m"; }

errx() { echo -e "${color:+\e[31m}[!] ${@:2}\e[0m"; exit $1; }

default_gateway() {
    local ret="$(json_get gateway)"
    echo "${ret:-51}" # US West
}

get_gateway() {
    local -a gateways=($(list_gateways))
    local index="0"

    case "$gateway_selection" in
        "random") index="$(( $RANDOM % ${#gateways[@]} ))" ;;
        *) index="$(( $(default_gateway) - 1 ))" ;;
    esac

    echo "${gateways[$index]}"
}

good() { echo -e "${color:+\e[32m}[+] $@\e[0m"; }

info() { echo -e "${color:+\e[37m}[*] $@\e[0m"; }

json_get() {
    [[ -z $conf ]] || jq -cMrS ".$vpn.$@" $conf | sed -r "s/^null$//g"
}

list_gateways() {
    find . -iname "*.ovpn" | sed -r "s#./|\.ovpn##g" | sort
}

long_opt() {
    local arg shift="0"
    case "$1" in
        "--"*"="*) arg="${1#*=}"; [[ -n $arg ]] || usage 1 ;;
        *) shift="1"; shift; [[ $# -gt 0 ]] || usage 1; arg="$1" ;;
    esac
    echo "$arg"
    return $shift
}

setup_creds() {
    rm -f creds.txt

    local password username

    if [[ -n $conf ]]; then
        local creds="$(json_get credsfile)"
        local cfile="$(json_get encrypted_credsfile)"
        if [[ -n $cfile ]]; then
            if [[ -f $confdir/$cfile ]]; then
                gpg -dq $confdir/$cfile >creds.txt
                chmod 400 creds.txt
                return
            elif [[ -f $cfile ]]; then
                gpg -dq $cfile >creds.txt
                chmod 400 creds.txt
                return
            else
                warn "$cfile does not exist"
            fi
        elif [[ -n $creds ]]; then
            if [[ -f $confdir/$creds ]]; then
                cp -f $confdir/$creds creds.txt
                chmod 400 creds.txt
                return
            elif [[ -f $creds ]]; then
                cp -f $creds creds.txt
                chmod 400 creds.txt
                return
            else
                warn "$creds does not exist"
            fi
        else
            password="$(json_get password)"
            local pfile="$(json_get encrypted_password)"
            if [[ -n $pfile ]]; then
                if [[ -f $confdir/$pfile ]]; then
                    password="$(gpg -dq $confdir/$pfile)"
                elif [[ -f $pfile ]]; then
                    password="$(gpg -dq $pfile)"
                else
                    warn "$pfile does not exist"
                fi
            fi
            username="$(json_get username)"
            local ufile="$(json_get encrypted_username)"
            if [[ -n $ufile ]]; then
                if [[ -f $confdir/$ufile ]]; then
                    username="$(gpg -dq $confdir/$ufile)"
                elif [[ -f $ufile ]]; then
                    username="$(gpg -dq $ufile)"
                else
                    warn "$ufile does not exist"
                fi
            fi
        fi
    fi

    [[ -n $username ]] || read -p "Enter username: " username
    [[ -n $password ]] || read -p "Enter password: " -s password

    echo "$username" >creds.txt
    echo "$password" >>creds.txt
    chmod 400 creds.txt
}

start_vpn() {
    local gateway="$(get_gateway)"
    info "Using gateway: $gateway"
    setup_creds
    sudo openvpn $gateway.ovpn
    [[ $? -eq 0 ]] || stop_vpn
}

stop_vpn() {
    info "Killing process and cleaning up..."
    [[ -z $(pgrep openvpn) ]] || sudo kill -9 $(pgrep openvpn)
    sleep 1
    if [[ -n $(command -v ip) ]]; then
        local default="$(ip r | awk '/default/ {print $3}')"
        while read -r route; do
            sudo ip r d $route
        done < <(ip r | tail -n +2 | grep "via $default"); unset route
    fi
    rm -f creds.txt
    info "done"
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
    echo "    --nocolor       Disable colorized output"
    echo "    -r, --random    Use random VPN gateway"
    echo
    exit $1
}

warn() { echo -e "${color:+\e[33m}[-] $@\e[0m"; }

declare -a args
unset conf gateway_selection help
color="true"
confdir="$HOME/.config/vpn"
[[ ! -f $confdir/vpn.conf ]] || conf="$confdir/vpn.conf"
vpn="$(basename $(pwd))"

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        "--") shift && args+=("$@") && break ;;
        "-h"|"--help") help="true" ;;
        "--nocolor") unset color ;;
        "-r"|"--random") gateway_selection="random" ;;
        *) args+=("$1") ;;
    esac
    shift
done
[[ -z ${args[@]} ]] || set -- "${args[@]}"

# Check for valid params and missing dependencies
[[ -z $help ]] || usage 0
[[ $# -eq 1 ]] || usage 1
for dep in jq openvpn; do
    [[ -n $(command -v $dep) ]] || errx 3 "$dep is not installed"
done; unset dep

trap stop_vpn SIGINT

mkdir -p $confdir
case "$1" in
    "list") list_gateways ;;
    "start") start_vpn ;;
    "stop") stop_vpn ;;
    *) usage 5 ;;
esac
