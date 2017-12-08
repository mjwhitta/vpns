## VPNs

This repo contains a few scripts to get you started with the PIA or
WindScribe VPNs. After running the installer, the `vpn` script is
added to `/usr/local/bin/` (should be in your path).

### Installation

```
$ git clone git@gitlab.com:mjwhitta/vpns.git ~/.vpns
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
```

### Configuring

There is minimal configuration support. Simply put the preferred VPN
in `$HOME/.config/vpn/vpn.conf` to set the default VPN. You can also
specify the index of the preferred PIA or WindScribe gateway in
`$HOME/.config/vpn/pia.conf` and `$HOME/.config/vpn/windscribe.conf`
respectively. The following command will help with that:

```
$ cat -n <(vpn -v pia list)
     1	AU_Melbourne
     2	AU_Sydney
     3	Brazil
     4	CA_Montreal
     5	CA_Toronto
    ...
$ cat -n <(vpn -v windscribe list)
     1	Argentina
     2	Australia
     3	Austria
     4	Azerbaijan
     5	Belgium
    ...
```

**Note: The lists in the scripts are 0-indexed so make sure to
subtract 1 from the numbers you see here**

### Adding more VPN providers

Adding new providers is as easy as copying the `providers/pia` or
`providers/windscribe` directory and modifying the `vpn.sh` script to
fit your needs. Alternatively you can do whatever you want so long as
you understand that the top-level `vpn` script (installed to
`/usr/local/bin`) will simply `cd` to your new `providers/whatever`
directory and run the `vpn.sh` script as `root`.
