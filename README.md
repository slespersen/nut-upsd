## nut-upsd
This is forked from [instantlinux docker-tools - nut-upsd](https://github.com/instantlinux/docker-tools/tree/main/images/nut-upsd) and modified to handle admin user.

The Network UPS Tools (nut) package in an Alpine container, with enough configuration to support Nagios monitoring of your UPS units. This multi-architecture image supports Intel/AMD and ARM (Raspberry Pi etc).

### Usage

This needs to run in privileged mode in order to access USB devices.

Pick a random password for the API user and place it in a Docker secret (if you're not using swarm or kubernetes, put it in the filepath as shown at bottom of docker-compose.yml, e.g. /var/adm/admin/secrets/nut-upsd-password).

This will expose TCP port 3493; to reach it with the standard Nagios plugin, set up a service to invoke:

```
/usr/lib/nagios/plugins/check_ups -H <dockerhost> -u <name> [ -p <port> ]
```

As a read-only service intended for monitoring, this container makes no attempt to lock down network security.

Verified with the most-common type of UPS, the APC consumer-grade product; Tripp Lite models also (probably) work. CyberPower models need a MAXAGE parameter set longer than default (25). Note that the usbhid-ups driver for APC requires you to provide the correct 12-digit hardware serial number. All other parameter defaults will work.

If you have a different model of UPS, contents of the files ups.conf, upsd.conf, upsmon.conf, and/or upsd.users can be overridden by mounting them to /etc/nut/local.

If you have more than one UPS connected to a host, run more than one copy of this container and bind the container port 3493 from each to a separate TCP port.

### Variables

These variables can be passed to the image from kubernetes.yaml or docker-compose.yml as needed:

Variable | Default | Description |
-------- | ------- | ----------- |
API_USER | upsmon| API user
API_PASSWORD | | API password, if not using secret
ADMIN_USER | admin| API user
ADMIN_PASSWORD | | API password, if not using secret
DESCRIPTION | UPS | user-assigned description
DRIVER | usbhid-ups | driver (see [compatibility list](http://networkupstools.org/stable-hcl.html))
GROUP | nut | local group
MAXAGE | 15 | seconds before declaring driver non-responsive
NAME | ups | user-assigned config name
POLLINTERVAL | | Poll Interval for ups.conf
PORT | auto | device port (e.g. /dev/ttyUSB0) on host
SDORDER | | UPS shutdown sequence, set to -1 to disable shutdown
SECRETNAME | nut-upsd-password | name of secret to use for API user
SERIAL | | hardware serial number of UPS
SERVER | master | master or slave priority for scripts
USER | nut | local user
VENDORID | | vendor ID for ups.conf
### Notes

If you need a driver other than `usbhid-ups`, the full list of supported drivers can be listed as follows:
```
docker run --rm --entrypoint /bin/ls instantlinux/nut-upsd /usr/lib/nut
```
The entrypoint script can set parameters based on the above environment variables; each driver has its own parameters (which can be configured by mounting your own ups.conf file) as documented:
```
MYDRIVER=liebert
docker run --rm --entrypoint /usr/lib/nut/$MYDRIVER instantlinux/nut-upsd -h
Network UPS Tools - Liebert MultiLink UPS driver 1.02 (3.15.0_alpha20210804-3402-gced1683082)
Warning: This is an experimental driver.
Some features may not function correctly.


usage: liebert -a <id> [OPTIONS]
  -a <id>        - autoconfig using ups.conf section <id>
                 - note: -x after -a overrides ups.conf settings

  -V             - print version, then exit
  -L             - print parseable list of driver variables
  -D             - raise debugging level
  -q             - raise log level threshold
  -h             - display this help
  -k             - force shutdown
  -i <int>       - poll interval
  -r <dir>       - chroot to <dir>
  -u <user>      - switch to <user> (if started as root)
  -x <var>=<val> - set driver variable <var> to <val>
                 - example: -x cable=940-0095B

Acceptable values for -x or ups.conf in this driver:

              Override manufacturer name : -x mfr=<value>
                     Override model name : -x model=<value>
```

For Tripp Lite models, you may need to specify VENDORID 09ae in the environment. Also check to see if you need a POLLINTERVAL setting. For any make or model, here's how to identify the idVendor and iSerial values from a root shell on your host:

```
# lsusb
 ...
Bus 001 Device 005: ID 051d:0002 American Power Conversion Uninterruptible Power Supply
# lsusb -D /dev/bus/usb/001/005
Device: ID 051d:0002 American Power Conversion Uninterruptible Power Supply
 ...
  idVendor           0x051d American Power Conversion
  idProduct          0x0002 Uninterruptible Power Supply
  bcdDevice            0.90
  iManufacturer           1 American Power Conversion
  iProduct                2 Back-UPS RS 1500G FW:865.L6 .D USB FW:L6
  iSerial                 3 4B1624P26350
```

If you require udev rules to set permissions, configure your host prior to running the container. For example:
```
cat >/etc/udev/rules.d/99-usb-serial.rules <<EOF
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}==“09ae”, ATTRS{idProduct}==“2012”, MODE="0660", GROUP="nut"
EOF
udevadm control --reload-rules && udevadm trigger
```

### Secrets

If the API or Admin user needs a password, you have two ways to specify it: pass the value itself as environment variable API_PASSWORD, or define a Docker secret as follows:

| Secret | Description |
| ------ | ----------- |
| nut-upsd-api | Password for API user |
| nut-upsd-admin | Password for admin user |

[![](https://img.shields.io/badge/license-GPL--2.0-red.svg)](https://choosealicense.com/licenses/gpl-2.0/ "License badge") [![](https://img.shields.io/badge/code-networkupstools%2Fnut-blue.svg)](https://github.com/networkupstools/nut "Code repo")
