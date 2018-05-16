## VPNs

This repo contains a few scripts to get you started with the PIA,
ProtonVPN, VPNBook, or WindScribe VPNs. After running the installer,
the `vpn` script is added to `/usr/local/bin/` (make sure it's in your
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
    list            List the gateway options
    start           Connect to VPN
    stop            Disconnect from VPN

Options:
    -h, --help      Display this help message
    -r, --random    Use random VPN gateway
```

### Configuring

There is minimal configuration support. Your
`$HOME/.config/vpn/vpn.conf` should look something like:

```
{
    "default_vpn": "pia",
    "pia": {
      "encrypted_credsfile": "creds.asc",
      "gateway": 1
    },
    "protonvpn": {
      "credsfile": "mycreds.txt",
      "gateway": 1
    },
    "vpnbook": {
      "gateway": 1,
      "password": "some_password_here",
      "username": "some_username_here"
    },
    "windscribe": {
      "encrypted_password": "password.asc",
      "encrypted_username": "username.asc",
      "gateway": 1
    }
}
```

**Note: I recommend using the `encrypted` options**

The following command will help you find your preferred gateway:

```
$ vpn -v pia list | less -N
     1	AU_Melbourne
     2	AU_Sydney
     3	Brazil
     4	CA_Montreal
     5	CA_Toronto
    ...
```

### Adding more VPN providers

Adding new providers is as easy as copying the `providers/pia`
directory to `providers/whatever` and then modifying its `vpn.sh`
script to fit your needs. Alternatively you can do whatever you want
so long as you understand that the top-level `vpn` script (installed
to `/usr/local/bin`) will simply `cd` to your new `providers/whatever`
directory and run the `vpn.sh`.
