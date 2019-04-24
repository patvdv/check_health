![License](https://img.shields.io/github/license/patvdv/check_health.svg)
![Code](https://img.shields.io/badge/Code-Shell-green.svg)
[![Release](https://img.shields.io/github/release/patvdv/check_health.svg)](https://github.com/patvdv/check_health/releases)
<br />
<p align="center"><img src="logo/horizontal.png" alt="QList" height="130px"></p>

# Health checker for UNIX/Linux

Health checker for UNIX/Linux is a small framework of monitoring scripts. It is meant to be used for low latency & low frequency checks, it is easy to extend where necessary (plugins) and it can be integrated with other toolsets.

## Requirements

* *ksh88/ksh93* (mksh/pdksh will work also but YMMV)
* some disk space for storing logs & event files
* system dependent tools/utilities (see individual health checks)
* UNIX *cron* or other scheduler
* execute as user *root* only

## Downloads

See the [Release](https://github.com/patvdv/check_health/releases) page.

## Installation

### HP-UX

Install the core bundle:

    swinstall -x mount_all_filesystems=false -s /tmp/hc-hpux-<version>.sd \*

Install the HP-UX plugin bundle:

    swinstall -x mount_all_filesystems=false -s /tmp/hc-hpux-platform-<version>.sd \*

### Linux

Install the core bundle:

    yum localinstall hc-linux-<version>.noarch.rpm
    dpkg --install hc-linux-<version>.noarch.rpm
    zypper install hc-linux-<version>.noarch.rpm
    pacman -U hc-linux-<version>-any.pkg.tar.xz

Install the Linux OS plugins bundle:

    yum localinstall hc-linux-platform-<version>.noarch.rpm
    dpkg --install hc-linux-platform-<version>.noarch.rpm
    zypper install hc-linux-platform-<version>.noarch.rpm
    pacman -U hc-linux-platform-<version>-any.pkg.tar.xz

### AIX

Install the core bundle:

    installp -Xap -d hc-aix-<version>.bff all

Install the AIX OS plugins bundle:

    installp -Xap -d hc-aix-platform-<version> all

### Clusterware/Exadata

Install the core bundle:

    yum localinstall hc-linux-<version>.noarch.rpm

Install Clusterware/Exadata Linux plugin bundle(s):

    yum localinstall hc-clusterware-platform-<version>.noarch.rpm
    yum localinstall hc-exadata-platform-<version>.noarch.rpm

### Serviceguard

Install the core bundle:

    swinstall -x mount_all_filesystems=false -s /tmp/hc-hpux-<version>.sd \*
    yum localinstall hc-linux-<version>.noarch.rpm

Install Serviceguard plugin bundle(s):

    swinstall -x mount_all_filesystems=false -s /tmp/hc-serviceguard-platform-<version>.sd \*
    yum localinstall hc-serviceguard-platform-<version>.noarch.rpm

### Miscellaneous

Additionally, there may be bundles for display or notification plugins, e.g.:
* hc-display-csv
* hc-display-init
* hc-display-json
* hc-display-terse
* hc-notify-eif
* hc-notify-sms

## Execute (examples)

* **Listing** available health checks:
```
/opt/hc/bin/check_health.sh --list
```

* **Running** a single health check:
```
/opt/hc/bin/check_health.sh --hc=check_hpux_ioscan --run
```

* **Running** multiple health checks (at once):
```
/opt/hc/bin/check_health.sh --hc=check_hpux_ioscan,check_hpux_ovpa_status --run
```

* **Running** a single health check with a custom configuration file:
```
/opt/hc/bin/check_health.sh --hc=check_hpux_ioscan --config-file=/etc/opt/hc/check_hpux_ioscan_new.conf --run
```

* **Showing** information on a health check:
```
/opt/hc/bin/check_health.sh --hc=check_hpux_ioscan --show
```

* **Enabling/disabling** a health check:
```
/opt/hc/bin/check_health.sh --hc=check_hpux_ioscan --check
/opt/hc/bin/check_health.sh --hc=check_hpux_ioscan --disable
/opt/hc/bin/check_health.sh --hc=check_hpux_ioscan --enable
```   

* **Reporting** on failed health checks:
```
/opt/hc/bin/check_health.sh --report
/opt/hc/bin/check_health.sh --report --last
/opt/hc/bin/check_health.sh --report --today
/opt/hc/bin/check_health.sh --report --newer=20180101
/opt/hc/bin/check_health.sh --report --id=20160704154001 --detail
```

* **Alerting** on failed health checks:
```
/opt/hc/bin/check_health.sh --hc=check_hpux_root_crontab --run --notify=mail --mail-to="alert@acme.com"
```    

## References

### Documentation

More documentation can be found at http://www.kudos.be/Projects/Health_checker.html

### Logo

The logo was kindly provided by *Komiser Back*.
