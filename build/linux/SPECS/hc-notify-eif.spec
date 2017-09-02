%define build_timestamp %(date +"%Y%m%d")

Name:           hc-notify-eif
Version:        %{build_timestamp}
Release:        1

Summary:        The KUDOS Health Checker (HC) for UNIX (EIF notify core plugin)
Group:          Tools/Monitoring

License:        GNU General Public License either version 2 of the License, or (at your option) any later version
URL:            http://www.kudos.be

Requires:       ksh,hc-linux
BuildArch:      noarch
BuildRoot:      %{_topdir}/%{name}-%{version}-root
      
%description 
The Health Checker is collection of scripts (plugins) designed to perform regular - but not intensive - health checks on UNIX/Linux systems. It provides plugins for AIX, HP-UX and Linux as well customer specific checks. Checks may include topics such file system mounts, process checks, file consistency etc.
This package contains core plugins (notify).

%prep

%build

%install
rm -rf $RPM_BUILD_ROOT
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/lib/core/notify_eif.sh $RPM_BUILD_ROOT/opt/hc/lib/core/notify_eif.sh
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core/providers
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core/providers
cp ../SOURCES/etc/core/providers/notify_eif.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/core/providers/notify_eif.conf.dist

%post
# ------------------------- CONFIGURATION starts here -------------------------
# location of the HC configuration files
HC_ETC_DIR="/etc/opt/hc"
# location of check_health.sh
HC_BIN="/opt/hc/bin/check_health.sh"
PATH="$PATH:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin"
# ------------------------- CONFIGURATION ends here ---------------------------
echo "INFO: starting post-install script ..."
# copy plugin configuration file
if [[ ! -f ${HC_ETC_DIR}/core/providers/notify_eif.conf ]]
then
    cp -p ${HC_ETC_DIR}/core/providers/notify_eif.conf.dist ${HC_ETC_DIR}/core/providers/notify_eif.conf >/dev/null
    (( $? == 0 )) || \
    {
        echo "ERROR: could not copy plugin config file in ${HC_ETC_DIR}/core/providers"
        exit 1
    }
fi
# refresh symbolic FPATH links
if [[ -x ${HC_BIN} ]]
then
    ${HC_BIN} --fix-symlinks
    (( $? == 0 )) || echo "WARN: updating symlinks failed"
fi
echo "INFO: finished post-install script"

%postun
# ------------------------- CONFIGURATION starts here -------------------------
# location of the HC configuration files
HC_ETC_DIR="/etc/opt/hc"
# location of check_health.sh
HC_BIN="/opt/hc/bin/check_health.sh"
PATH="$PATH:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin"
# ------------------------- CONFIGURATION ends here ---------------------------
# update or uninstall?
if (( $1 == 0 ))
then
    echo "INFO: starting post-uninstall script ..."
    # copy plugin configuration file (.dist only)
    if [[ -d ${HC_ETC_DIR}/core/providers ]]
    then
        rm -f ${HC_ETC_DIR}/core/providers/notify_eif.conf.dist 2>/dev/null
        (( $? == 0 )) || \
        {
            echo "ERROR: could not remove plugin config file in ${HC_ETC_DIR}/core/providers"
            exit 1
        }
    fi
else
    echo "INFO: starting post-uninstall script (RPM upgrade)"
fi
# refresh symbolic FPATH links
if [[ -x ${HC_BIN} ]]
then
    ${HC_BIN} --fix-symlinks
    (( $? == 0 )) || echo "WARN: updating symlinks failed"
fi
echo "INFO: finished post-uninstall script"

%files
%defattr(-,root,root,755)
%dir /opt/hc/lib
%dir /opt/hc/lib/core
%attr(755, root, root) /opt/hc/lib/core/notify_eif.sh
%dir /etc/opt/hc
%dir /etc/opt/hc/core
%dir /etc/opt/hc/core/providers
%attr(644, root, root) /etc/opt/hc/core/providers/notify_eif.conf.dist

%changelog
* Tue Jun 20 2017 <patrick@kudos.be> - 0.0.2
- Made %postun RPM update aware
* Sun Apr 30 2017 <patrick@kudos.be> - 0.0.1
- Initial build
