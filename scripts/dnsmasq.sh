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
err() { echo -e "${color:+\e[31m}[!] $*${color:+\e[0m}" >&2; }
errx() { err "${*:2}"; exit "$1"; }
good() { echo -e "${color:+\e[32m}[+] $*${color:+\e[0m}"; }
info() { echo -e "${color:+\e[37m}[*] $*${color:+\e[0m}"; }
long_opt() {
    local arg shift="0"
    case "$1" in
        "--"*"="*) arg="${1#*=}"; [[ -n $arg ]] || return 127 ;;
        *) shift="1"; shift; [[ $# -gt 0 ]] || return 127; arg="$1" ;;
    esac
    echo "$arg"
    return $shift
}
subinfo() { echo -e "${color:+\e[36m}[=] $*${color:+\e[0m}"; }
warn() { echo -e "${color:+\e[33m}[-] $*${color:+\e[0m}"; }
### Helpers end

darwin_start_dnsmasq() {
    local conf

    while read -r conf; do
        sudo install -g admin -m 644 -o "$(id -nu)" "$conf" \
            "/usr/local/etc/dnsmasq.d/${conf%%.dnsmasq}.conf"
    done < <(find . -name "*.dnsmasq"); unset conf

    sudo brew services restart dnsmasq

    case "$(brew services list | ggrep -ioPs "^dnsmasq\s+\K\S+")" in
        "stopped") errx 4 "Failed to start dnsmasq" ;;
    esac
}

darwin_stop_dnsmasq() {
    local conf

    while read -r conf; do
        sudo rm -f "/usr/local/etc/dnsmasq.d/${conf%%.dnsmasq}.conf"
    done < <(find . -name "*.dnsmasq"); unset conf

    sudo brew services restart dnsmasq
}

linux_start_dnsmasq() {
    local conf

    while read -r conf; do
        sudo install -g root -m 644 -o root "$conf" \
            "/etc/dnsmasq.d/${conf%%.dnsmasq}.conf"
    done < <(find . -name "*.dnsmasq"); unset conf

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

linux_stop_dnsmasq() {
    local conf

    while read -r conf; do
        sudo rm -f "/etc/dnsmasq.d/${conf%%.dnsmasq}.conf"
    done < <(find . -name "*.dnsmasq"); unset conf

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

start_dnsmasq() {
    case "$(uname -s)" in
        "Darwin") darwin_start_dnsmasq ;;
        *) linux_start_dnsmasq ;;
    esac
}

stop_dnsmasq() {
    case "$(uname -s)" in
        "Darwin") darwin_stop_dnsmasq ;;
        *) linux_stop_dnsmasq ;;
    esac
}

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS] <start|stop>

DESCRIPTION
    Dynamically add or remove dnsmasq configs.

OPTIONS
    -h, --help         Display this help message
        --no-color     Disable colorized output

EOF
    exit "$1"
}

declare -a args
unset help
color="true"

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        "--") shift; args+=("$@"); break ;;
        "-h"|"--help") help="true" ;;
        "--no-color") unset color ;;
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
case "$(uname -s)" in
    "Darwin")
        deps+=("/usr/local/etc/dnsmasq.d")
        deps+=("brew")
        deps+=("ggrep")
        ;;
    *) deps+=("/etc/dnsmasq.d") ;;
esac
check_deps

# Check for valid params
[[ $# -eq 1 ]] || usage 1

case "$1" in
    "start") start_dnsmasq ;;
    "stop") stop_dnsmasq ;;
    *) errx 2 "Invalid action" ;;
esac
