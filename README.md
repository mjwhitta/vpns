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

This is a wrapper script for other vpn scripts. Supported VPNs include
PIA, ProtonVPN, VPNBook, and WindScribe.

Options:
    -h, --help       Display this help message
    --nocolor        Disable colorized output
    -r, --random     Use random VPN gateway
    -v, --vpn=VPN    Use the specified VPN (default: pia)

$ vpn help pia
Usage: vpn.sh [OPTIONS] <action>

Connect to the PIA VPN using a set of gateways

Actions:
    list            List the gateway options
    start           Connect to VPN
    stop            Disconnect from VPN

Options:
    -h, --help      Display this help message
    --nocolor       Disable colorized output
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

The encrypted options point to gpg encrypted files created with any of
the following commands:

```
$ gpg -aer myemail@some.domain ./creds.txt
$ gpg -aer myemail@some.domain ./password.txt
$ gpg -aer myemail@some.domain ./username.txt
```

In `$HOME/.config/vpn/vpn.conf`, the path to the encrypted file can
either be relative to `$HOME/.config/vpn` or that provider's
directory, or an absolute path, so long as the absolute path doesn't
contain `~` or environment variables like `$HOME` (meaning you should
use `/home/user/...`).

The following command will help you find your preferred gateway:

```
$ vpn list pia | less -N
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
to `$HOME/.local/bin`) will simply `cd` to your new
`providers/whatever` directory and run the `vpn.sh`.
