## VPNs

This repo contains a few scripts to get you started with the PIA,
ProtonVPN, VPNBook, or WindScribe VPNs. After running the installer,
the `vpn` script is added to `$HOME/.local/bin/` (make sure it's in
your path).

### Installation

```
$ git clone https://gitlab.com/mjwhitta/vpns.git ~/.vpns
$ cd ~/.vpns
$ ./installer
$ vpn help
Usage: vpn [OPTIONS] <action> [vpn]

This is a wrapper script for other vpn scripts. Any OpenVPN provider
should be supported. Wireguard configs are supported. OpenConnect will
require some work on the user's part.

Actions:
    help             Display this help message
    list             List the vpn options
    start            Connect to VPN
    stop             Disconnect from VPN (wireguard only)

Options:
    -g, --gw=GW      Use the specified gateway
    -h, --help       Display this help message
    --no-color       Disable colorized output
    -r, --random     Use random VPN gateway
    -t, --tmux       Use tmux to start VPN connection in background
                     (avoid symlinks for now)
    -v, --vpn=VPN    Use the specified VPN (default: pia)
```

### Configuring

There is minimal configuration support. Your
`$HOME/.config/vpn/vpn.cfg` should look something like:

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

The encrypted options point to gpg encrypted files created with any of
the following commands:

```
$ cat >./creds.txt <<EOF
myusername
mypassword
EOF
$ gpg -aer myemail@some.domain ./creds.txt
```

In `$HOME/.config/vpn/vpn.cfg`, the path to the encrypted file can
either be relative to `$HOME/.config/vpn` or that provider's
directory, or an absolute path, so long as the absolute path doesn't
contain `~` or environment variables like `$HOME` (meaning you should
use `/home/user/...`).

The following command will help you find your preferred gateway:

```
$ vpn list pia
     1	Albania_tcp
     2	Albania_udp
     3	Argentina_tcp
     4	Argentina_udp
     5	AU_Melbourne_tcp
    ...
```

### Adding more VPN providers

Adding new providers is as easy as copying the `providers/pia`
directory to `providers/whatever` and then modifying its `vpn.cfg`
script to fit your needs. Alternatively you can do whatever you want
so long as you understand that the top-level `vpn` script (installed
to `$HOME/.local/bin`) will simply `cd` to your new
`providers/whatever` directory and run either the top-level
`openvpn.sh` or `wireguard.sh` script.

While Openconnect does work, you will need to write your own `vpn.sh`
script in that provider's directory. Then modify the `type` in
`vpn.cfg` to be `openconnect`. I would like to improve on this later
but am not yet sure how to make MFA configurable in a generic way.

### DNS

At this time, `dnsmasq` is supported and any files in your
`provider/whatever` directory that end with `.dnsmasq` will be
dynamically added. If your system is configured to use `dnsmasq`
already, it will simply be restarted when connecting or disconnecting.
If not, the service is simply started and stopped when needed.
