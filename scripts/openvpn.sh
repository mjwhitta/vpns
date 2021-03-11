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
errx() { err "${*:2}"; rm -f "$credentials"; exit "$1"; }
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
    cat -n <(find . -iname "*.ovpn" | sed -r "s#./|\.ovpn##g" | sort)
}

setup_creds() {
    mkdir -p "$(dirname "$credentials")"
    rm -f "$credentials"

    local cfile creds password pfile tmp ufile username

    if [[ -n $conf ]]; then
        cfile="$(json_get encrypted_credsfile)"
        creds="$(json_get credsfile)"
        if [[ -n $cfile ]]; then
            tmp="$confdir/$cfile"
            [[ -f $tmp ]] || tmp="$cfile"
            if [[ -f $tmp ]]; then
                while read -r line; do
                    if [[ -z $username ]]; then
                        username="$line"
                        continue
                    fi
                    [[ -n $password ]] || password="$line"
                    [[ -z $password ]] || break
                done < <(gpg -dq "$tmp" 2>/dev/null)
            else
                warn "$cfile does not exist"
            fi
        elif [[ -n $creds ]]; then
            tmp="$confdir/$creds"
            [[ -f $tmp ]] || tmp="$creds"
            if [[ -f $tmp ]]; then
                while read -r line; do
                    if [[ -z $username ]]; then
                        username="$line"
                        continue
                    fi
                    [[ -n $password ]] || password="$line"
                    [[ -z $password ]] || break
                done < <(cat "$tmp"; echo)
            else
                warn "$creds does not exist"
            fi
        else
            password="$(json_get password)"
            pfile="$(json_get encrypted_password)"
            if [[ -n $pfile ]]; then
                tmp="$confdir/$pfile"
                [[ -f $tmp ]] || tmp="$pfile"
                if [[ -f $tmp ]]; then
                    password="$(gpg -dq "$tmp" 2>/dev/null)"
                else
                    warn "$pfile does not exist"
                fi
            fi
            ufile="$(json_get encrypted_username)"
            username="$(json_get username)"
            if [[ -n $ufile ]]; then
                tmp="$confdir/$ufile"
                [[ -f $tmp ]] || tmp="$ufile"
                if [[ -f $tmp ]]; then
                    username="$(gpg -dq "$tmp" 2>/dev/null)"
                else
                    warn "$ufile does not exist"
                fi
            fi
        fi
    fi

    [[ -n $username ]] || read -p "Enter username: " -r username
    if [[ -z $password ]]; then
        read -p "Enter password: " -rs password; echo
    fi

    echo "$username" >"$credentials"
    echo "$password" >>"$credentials"
    chmod 400 "$credentials"
}

start_vpn() {
    local gw="$(get_gateway)"

    ../../scripts/dnsmasq.sh start

    info "Using gateway: $gw"
    setup_creds
    (sleep 10 && rm -f "$credentials") &
    sudo openvpn "$gw.ovpn"
    [[ $? -eq 0 ]] || stop_vpn 0
}

stop_vpn() {
    case "${1:-1}" in
        "1") echo ;;
    esac

    ../../scripts/dnsmasq.sh stop

    info "Killing process and cleaning up..."
    sudo pkill -9 -P $$ openvpn
    sleep 1
    if [[ -n $(command -v ip) ]]; then
        local default="$(ip r | awk '/default/ {print $3}')"
        while read -r route; do
            # shellcheck disable=SC2086
            sudo ip r d $route
        done < <(
            ip r | tail -n +2 | grep -is "via $default" | \
            grep -iPsv "/|^default|static|"
        ); unset route
    fi
    rm -f "$credentials"
    info "done"

    case "${1:-1}" in
        "1") kill -9 $$ ;;
    esac
}

usage() {
    local name="$(conf_get "name")"
    local provider="$(basename "$(pwd)")"
    # stop            Disconnect from VPN
    cat <<EOF
Usage: vpn [OPTIONS] <action> $provider

DESCRIPTION
    Connect to the $name VPN using a set of gateways.

OPTIONS
    -g, --gw=GW     Use the specified gateway
    -h, --help      Display this help message
    --no-color      Disable colorized output
    -r, --random    Use random VPN gateway

ACTIONS
    help     Display this help message
    list     List the gateway options
    start    Connect to VPN

EOF
    exit "$1"
}

declare -a args
unset conf gateway help
color="true"
confdir="$HOME/.config/vpn"
[[ ! -f $confdir/vpn.cfg ]] || conf="$confdir/vpn.cfg"
credentials="creds.txt"
vpn="$(basename "$(pwd)")"

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

# Help info
[[ -z $help ]] || usage 0

# Check for missing dependencies
declare -a deps
deps+=("jq")
deps+=("openvpn")
check_deps

# Check for valid params
[[ $# -eq 1 ]] || usage 1

trap stop_vpn SIGINT

mkdir -p "$confdir"
case "$1" in
    "list") list_gateways ;;
    "start") start_vpn ;;
    # "stop") stop_vpn ;;
    *) usage 2 ;;
esac
