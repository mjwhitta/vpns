## VPNs

This repo contains a few scripts to get you started with the PIA,
ProtonVPN, VPNBook, or WindScribe VPNs. After running the installer,
the `vpn` script is added to `/usr/local/bin/` (should be in your
path).

### Installation

```
$ git clone https://gitlab.com/mjwhitta/vpns.git ~/.vpns
$ cd ~/.vpns
$ ./installer
$ vpn -h
Usage: vpn [OPTIONS] -- [pass-thru options]

This is a wrapper script for other vpn scripts. Currently
included VPNs are: PIA and WindScribe

Options:
    -h, --help       Display this help message
    -l, --list       List included VPNs
    -v, --vpn=VPN    Use the specified VPN (default: pia)

$ vpn -v pia -- -h
Usage: vpn.sh [OPTIONS] <action>

Connect to the PIA VPN using a set of gateways

Actions:
    list             List the gateway options
    start            Connect to VPN
    stop             Disconnect from VPN

Options:
    -h, --help       Display this help message
    -r, --random     Use random VPN gateway

$ vpn -v protonvpn -- -h
Usage: vpn.sh [OPTIONS] <action>

Connect to the ProtonVPN using a set of gateways

Actions:
    list             List the gateway options
    start            Connect to VPN
    stop             Disconnect from VPN

Options:
    -h, --help       Display this help message
    -r, --random     Use random VPN gateway

$ vpn -v windscribe -- -h
Usage: vpn.sh [OPTIONS] <action>

Connect to the WindScribe VPN using a set of gateways

Actions:
    list             List the gateway options
    start            Connect to VPN
    stop             Disconnect from VPN

Options:
    -h, --help       Display this help message
    -r, --random     Use random VPN gateway
$ vpn -v vpnbook -- -h
Usage: vpn.sh [OPTIONS] <action>

Connect to the VPNBook VPN using a set of gateways

Actions:
    list             List the gateway options
    start            Connect to VPN
    stop             Disconnect from VPN

Options:
    -h, --help       Display this help message
    -r, --random     Use random VPN gateway
```

### Configuring

There is minimal configuration support. Your
`$HOME/.config/vpn/vpn.conf` should look something like:

```
{
    "default_vpn": "pia",
    "pia": {"gateway": 1},
    "protonvpn": {"gateway": 1}
    "vpnbook": {"gateway": 1},
    "windscribe": {"gateway": 1}
}
```

The following commands will help you find your preferred gateway:

```
$ cat -n <(vpn -v pia list)
     1	AU_Melbourne
     2	AU_Sydney
     3	Brazil
     4	CA_Montreal
     5	CA_Toronto
    ...
$ cat -n <(vpn -v protonvpn list)
     1	jp-01.protonvpn.com.tcp443
     2	jp-01.protonvpn.com.udp1194
     3	jp-02.protonvpn.com.tcp443
     4	jp-02.protonvpn.com.udp1194
     5	jp-free-01.protonvpn.com.tcp443
    ...
$ cat -n <(vpn -v vpnbook list)
     1	ca1-tcp443
     2	ca1-tcp80
     3	ca1-udp25000
     4	ca1-udp53
     5	de233-tcp443
    ...
$ cat -n <(vpn -v windscribe list)
     1	Argentina
     2	Australia
     3	Austria
     4	Azerbaijan
     5	Belgium
    ...
```

### Adding more VPN providers

Adding new providers is as easy as copying the `providers/pia`
directory and modifying the `vpn.sh` script to fit your needs.
Alternatively you can do whatever you want so long as you understand
that the top-level `vpn` script (installed to `/usr/local/bin`) will
simply `cd` to your new `providers/whatever` directory and run the
`vpn.sh` script as `root`.
