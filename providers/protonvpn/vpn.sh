#!/usr/bin/env bash

### Helpers begin
checkdeps() {
    for d in "${deps[@]}"; do
        [[ -n $(command -v $d) ]] || errx 128 "$d is not installed"
    done; unset d
}
err() { echo -e "${color:+\e[31m}[!] $@\e[0m"; }
errx() { echo -e "${color:+\e[31m}[!] ${@:2}\e[0m"; exit $1; }
good() { echo -e "${color:+\e[32m}[+] $@\e[0m"; }
info() { echo -e "${color:+\e[37m}[*] $@\e[0m"; }
long_opt() {
    local arg shift="0"
    case "$1" in
        "--"*"="*) arg="${1#*=}"; [[ -n $arg ]] || usage 127 ;;
        *) shift="1"; shift; [[ $# -gt 0 ]] || usage 127; arg="$1" ;;
    esac
    echo "$arg"
    return $shift
}
subinfo() { echo -e "${color:+\e[36m}[=] $@\e[0m"; }
warn() { echo -e "${color:+\e[33m}[-] $@\e[0m"; }
### Helpers end

default_gateway() {
    local ret="$(json_get gateway)"
    echo "${ret:-100}" # US-FREE-01
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

json_get() {
    [[ -z $conf ]] || jq -cMrS ".$vpn.$@" $conf | sed -r "s/^null$//g"
}

list_gateways() {
    find . -iname "*.ovpn" | sed -r "s#./|\.ovpn##g" | sort
}

setup_creds() {
    rm -f creds.txt

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
                done < <(gpg -dq $tmp 2>/dev/null)
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
                done < <(cat $tmp; echo)
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
                    password="$(gpg -dq $tmp 2>/dev/null)"
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
                    username="$(gpg -dq $tmp 2>/dev/null)"
                else
                    warn "$ufile does not exist"
                fi
            fi
        fi
    fi

    [[ -n $username ]] || read -p "Enter username: " username
    if [[ -z $password ]]; then
        read -p "Enter password: " -s password; echo
    fi

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
    cat <<EOF
Usage: ${0##*/} [OPTIONS] <action>

Connect to the ProtonVPN using a set of gateways

Actions:
    list            List the gateway options
    start           Connect to VPN
    stop            Disconnect from VPN

Options:
    -h, --help      Display this help message
    --nocolor       Disable colorized output
    -r, --random    Use random VPN gateway

EOF
    exit $1
}

declare -a args deps
unset conf gateway_selection help
color="true"
confdir="$HOME/.config/vpn"
[[ ! -f $confdir/vpn.conf ]] || conf="$confdir/vpn.conf"
deps+=("jq")
deps+=("openvpn")
vpn="$(basename $(pwd))"

# Check for missing dependencies
checkdeps

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

trap stop_vpn SIGINT

mkdir -p $confdir
case "$1" in
    "list") list_gateways ;;
    "start") start_vpn ;;
    "stop") stop_vpn ;;
    *) usage 5 ;;
esac
