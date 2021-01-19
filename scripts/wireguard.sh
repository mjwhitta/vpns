#!/usr/bin/env bash

### Helpers begin
check_deps() {
    local missing
    for d in "${deps[@]}"; do
        if [[ -z $(command -v "$d") ]]; then
            # Force absolute path
            if [[ ! -e "/$d" ]]; then
                err "$d was not found"
                missing="true"
            fi
        fi
    done; unset d
    [[ -z $missing ]] || exit 128
}
err() { echo -e "${color:+\e[31m}[!] $*\e[0m"; }
errx() { err "${*:2}"; exit "$1"; }
good() { echo -e "${color:+\e[32m}[+] $*\e[0m"; }
info() { echo -e "${color:+\e[37m}[*] $*\e[0m"; }
long_opt() {
    local arg shift="0"
    case "$1" in
        "--"*"="*) arg="${1#*=}"; [[ -n $arg ]] || return 127 ;;
        *) shift="1"; shift; [[ $# -gt 0 ]] || return 127; arg="$1" ;;
    esac
    echo "$arg"
    return $shift
}
subinfo() { echo -e "${color:+\e[36m}[=] $*\e[0m"; }
warn() { echo -e "${color:+\e[33m}[-] $*\e[0m"; }
### Helpers end

conf_get() {
    [[ -f "vpn.cfg" ]] || errx 3 "Provider not configured"
    jq -cMrS ".$1" "vpn.cfg" | sed -r "s/^null$//g"
}

default_gateway() {
    local ret="$(json_get gateway)"
    echo "${ret:-$(conf_get "default_gateway")}"
}

get_gateway() {
    local -a gateways
    local gw
    while read -r gw; do
        gateways+=("$gw")
    done < <(list_gateways | awk '{print $2}'); unset gw
    local index="0"

    case "$gateway" in
        "") index="$(($(default_gateway) - 1))" ;;
        "random") index="$((RANDOM % ${#gateways[@]}))" ;;
        *) index="$((gateway - 1))" ;;
    esac

    echo "${gateways[$index]}"
}

json_get() {
    if [[ -z $conf ]] || [[ ! -f "$conf" ]]; then
        return
    fi
    jq -cMrS ".$vpn.$*" "$conf" | sed -r "s/^null$//g"
}

list_gateways() {
    cat -n <(find . -iname "*.conf" | sed -r "s#./|\.conf##g" | sort)
}

start_vpn() {
    local gw="$(get_gateway)"

    ../../scripts/dnsmasq.sh start

    info "Using gateway: $gw"
    sudo wg-quick up "./$gw.conf"
}

stop_vpn() {
    local gw="$(get_gateway)"

    ../../scripts/dnsmasq.sh stop

    info "Killing process and cleaning up..."
    sudo wg-quick down "./$gw.conf"
    info "done"
}

usage() {
    local name="$(conf_get "name")"
    local provider="$(basename "$(pwd)")"

    cat <<EOF
Usage: vpn [OPTIONS] <action> $provider

Connect to the $name VPN using a set of gateways.

Actions:
    help            Display this help message
    list            List the gateway options
    start           Connect to VPN
    stop            Disconnect from VPN

Options:
    -g, --gw=GW     Use the specified gateway
    -h, --help      Display this help message
    --no-color      Disable colorized output
    -r, --random    Use random VPN gateway

EOF
    exit "$1"
}

declare -a args deps
unset conf gateway help
color="true"
confdir="$HOME/.config/vpn"
[[ ! -f $confdir/vpn.cfg ]] || conf="$confdir/vpn.cfg"
deps+=("jq")
deps+=("wg-quick")
vpn="$(basename "$(pwd)")"

# Check for missing dependencies
check_deps

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        "--") shift; args+=("$@"); break ;;
        "-g"|"--gw"*) gateway="$(long_opt "$@")" ;;
        "-h"|"--help") help="true" ;;
        "--no-color") unset color ;;
        "-r"|"--random") gateway="random" ;;
        *) args+=("$1") ;;
    esac
    case "$?" in
        0) ;;
        1) shift ;;
        *) usage $? ;;
    esac
    shift
done
[[ ${#args[@]} -eq 0 ]] || set -- "${args[@]}"

# Check for valid params
[[ -z $help ]] || usage 0
[[ $# -eq 1 ]] || usage 1

trap stop_vpn SIGINT

mkdir -p "$confdir"
case "$1" in
    "list") list_gateways ;;
    "start") start_vpn ;;
    "stop") stop_vpn ;;
    *) usage 2 ;;
esac
