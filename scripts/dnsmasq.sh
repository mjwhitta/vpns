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
        "--"*"="*) arg="${1#*=}"; [[ -n $arg ]] || usage 127 ;;
        *) shift="1"; shift; [[ $# -gt 0 ]] || usage 127; arg="$1" ;;
    esac
    echo "$arg"
    return $shift
}
subinfo() { echo -e "${color:+\e[36m}[=] $*\e[0m"; }
warn() { echo -e "${color:+\e[33m}[-] $*\e[0m"; }
### Helpers end

start_dnsmasq() {
    while read -r conf; do
        sudo install -g root -m 644 -o root "$conf" \
            "/etc/dnsmasq.d/${conf%%.dnsmasq}.conf"
    done < <(find . -name "*.dnsmasq")

    if [[ -n $(command -v systemctl) ]]; then
        sudo systemctl restart dnsmasq
        case "$(systemctl is-active dnsmasq)" in
            "inactive") errx 4 "Failed to start dnsmasq" ;;
        esac
        case "$(systemctl is-enabled dnsmasq)" in
            "disabled") warn "dnsmasq is started but not enabled" ;;
        esac
    elif [[ -n $(command -v rc-service) ]]; then
        sudo rc-service dnsmasq restart
        case "$(sudo rc-service dnsmasq status)" in
            *"stopped"*) errx 4 "Failed to start dnsmasq" ;;
        esac
        case "$(sudo rc-update show | grep "dnsmasq")" in
            *"default"*) ;;
            *) warn "dnsmasq is started but not enabled" ;;
        esac
    fi
}

stop_dnsmasq() {
    while read -r conf; do
        sudo rm -f "/etc/dnsmasq.d/${conf%%.dnsmasq}.conf"
    done < <(find . -name "*.dnsmasq")

    if [[ -n $(command -v systemctl) ]]; then
        case "$(systemctl is-enabled dnsmasq)" in
            "disabled") sudo systemctl stop dnsmasq ;;
            "enabled") sudo systemctl restart dnsmasq ;;
        esac
    elif [[ -n $(command -v rc-service) ]]; then
        case "$(sudo rc-update show | grep "dnsmasq")" in
            *"default"*) sudo rc-service dnsmasq restart ;;
            *) sudo rc-service dnsmasq stop ;;
        esac
    fi
}

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS] <start|stop>

Dynamically add or remove dnsmasq configs.

Options:
    -h, --help    Display this help message
    --no-color    Disable colorized output

EOF
    exit "$1"
}

declare -a args deps
unset help
color="true"
deps+=("/etc/dnsmasq.d")

# Check for missing dependencies
check_deps

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        "--") shift && args+=("$@") && break ;;
        "-h"|"--help") help="true" ;;
        "--no-color") unset color ;;
        *) args+=("$1") ;;
    esac
    shift
done
[[ ${#args[@]} -eq 0 ]] || set -- "${args[@]}"

# Check for valid params
[[ -z $help ]] || usage 0
[[ $# -eq 1 ]] || usage 1

case "$1" in
    "start") start_dnsmasq ;;
    "stop") stop_dnsmasq ;;
    *) errx 2 "Invalid action" ;;
esac
