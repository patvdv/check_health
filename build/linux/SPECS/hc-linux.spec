%define build_timestamp %(date +"%Y%m%d")

Name:           hc-linux
Version:        %{build_timestamp}
Release:        1

Summary:        The KUDOS Health Checker (HC) for UNIX
Group:          Tools/MonitoringGroup:          Tools/Monitoring

License:        GNU General Public License either version 2 of the License, or (at your option) any later version
URL:            http://www.kudos.be

Requires:       ksh
BuildArch:      noarch
BuildRoot:      %{_topdir}/%{name}-%{version}-root
      
%description 
The Health Checker is collection of scripts (plugins) designed to perform regular - but not intensive - health checks on UNIX/Linux systems. It provides plugins for AIX, HP-UX and Linux as well customer specific checks. Checks may include topics such file system mounts, process checks, file consistency etc.

%prep

%build

%install
rm -rf $RPM_BUILD_ROOT
install -d -m 755 $RPM_BUILD_ROOT/opt/hc
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/bin
cp ../SOURCES/bin/check_health.sh $RPM_BUILD_ROOT/opt/hc/bin
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/lib/core/include_core.sh $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/lib/core/include_data.sh $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/lib/core/include_os.sh $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/lib/core/notify_mail.sh $RPM_BUILD_ROOT/opt/hc/lib/core
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc
cp ../SOURCES/etc/check_host.conf.dist $RPM_BUILD_ROOT/etc/opt/hc
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core
cp ../SOURCES/etc/core/check_health.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/core
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core/providers
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/core/templates/mail_info.tpl $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/core/templates/mail_header.tpl $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/core/templates/mail_body.tpl $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/core/templates/mail_footer.tpl $RPM_BUILD_ROOT/etc/opt/hc/core/templates
install -d -m 755 $RPM_BUILD_ROOT/var/opt/hc

%post
# ------------------------- CONFIGURATION starts here -------------------------
# location of the HC scripts
HC_DIR="/opt/hc"
# location of the HC configuration files
HC_ETC_DIR="/etc/opt/hc"
# location of the HC log/state files
HC_VAR_DIR="/var/opt/hc"
# location of check_health.sh
HC_BIN="/opt/hc/bin/check_health.sh"
PATH="$PATH:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin"
# ------------------------- CONFIGURATION ends here ---------------------------
echo "INFO: starting post-install script ..."
# copy configuration files
if [[ ! -f ${HC_ETC_DIR}/core/check_health.conf ]]
then
    # copy main configuration file
    cp -p ${HC_ETC_DIR}/core/check_health.conf.dist ${HC_ETC_DIR}/core/check_health.conf >/dev/null
    (( $? == 0 )) || \
    {
        echo "ERROR: could not copy main config file in ${HC_ETC_DIR}/core"
        exit 1
    }
fi
if [[ ! -f ${HC_ETC_DIR}/check_host.conf ]]
then
    # copy host check configuration file
    cp -p ${HC_ETC_DIR}/check_host.conf.dist ${HC_ETC_DIR}/check_host.conf >/dev/null
    (( $? == 0 )) || \
    {
        echo "ERROR: could not copy host check config file in ${HC_ETC_DIR}"
        exit 1
    }
fi
# refresh symbolic FPATH links for core includes & plugins
if [[ -x ${HC_BIN} ]]
then
    ${HC_BIN} --fix-symlinks || echo "WARN: updating symlinks failed"
else
    echo "ERROR: could not locate or excute the HC main script (${HC_BIN})"
fi
echo "INFO: finished post-install script"

%postun
# ------------------------- CONFIGURATION starts here -------------------------
# location of the HC scripts
HC_DIR="/opt/hc"
# location of the HC configuration files
HC_ETC_DIR="/etc/opt/hc"
# location of the HC log/state files
HC_VAR_DIR="/var/opt/hc"
# ------------------------- CONFIGURATION ends here ---------------------------
# update or uninstall?
if (( $1 == 0 ))
then
    echo "INFO: starting post-uninstall script ..."
    if [[ -d ${HC_DIR} ]]
    then
        rm -rf ${HC_DIR} 2>/dev/null
        (( $? == 0 )) || echo "WARN: failed to remove ${HC_DIR}"
    fi
    if [[ -d ${HC_ETC_DIR} ]]
    then
        rm -rf ${HC_ETC_DIR}/*.dist >/dev/null
        (( $? == 0 )) || echo "WARN: could not remove .dist files in directory ${HC_ETC_DIR}"
    fi
    if [[ -d ${HC_ETC_DIR}/core ]]
    then
        rm -rf ${HC_ETC_DIR}/core/*.dist >/dev/null
        (( $? == 0 )) || echo "WARN: could not remove .dist files in directory ${HC_ETC_DIR}/core"
    fi
    if [[ -d ${HC_ETC_DIR}/core/providers ]]
    then
        rm -rf ${HC_ETC_DIR}/core/providers/*.dist >/dev/null
        (( $? == 0 )) || echo "WARN: could not remove .dist files in directory ${HC_ETC_DIR}/core/providers"
    fi
    if [[ -d ${HC_VAR_DIR} ]]
    then
        rm -rf ${HC_VAR_DIR}/state/temporary 2>/dev/null
        (( $? == 0 )) || echo "WARN: failed to remove ${HC_VAR_DIR}/state/temporary"
    fi
    echo "INFO: finished post-uninstall script"
else
    echo "INFO: skipping post-uninstall script (RPM upgrade)"
fi
    
%files
%defattr(-,root,root,755)
%dir /opt/hc
%dir /opt/hc/bin
%attr(755, root, root) /opt/hc/bin/check_health.sh
%dir /opt/hc/lib
%dir /opt/hc/lib/core
%attr(755, root, root) /opt/hc/lib/core/include_core.sh
%attr(755, root, root) /opt/hc/lib/core/include_data.sh
%attr(755, root, root) /opt/hc/lib/core/include_os.sh
%attr(755, root, root) /opt/hc/lib/core/notify_mail.sh
%dir /etc/opt/hc
%attr(644, root, root) /etc/opt/hc/check_host.conf.dist
%dir /etc/opt/hc/core
%attr(644, root, root) /etc/opt/hc/core/check_health.conf.dist
%dir /etc/opt/hc/core/providers
%dir /etc/opt/hc/core/templates
%attr(644, root, root) /etc/opt/hc/core/templates/mail_info.tpl
%attr(644, root, root) /etc/opt/hc/core/templates/mail_header.tpl
%attr(644, root, root) /etc/opt/hc/core/templates/mail_body.tpl
%attr(644, root, root) /etc/opt/hc/core/templates/mail_footer.tpl
%dir /var/opt/hc

%changelog
* Tue Jun 20 2017 <patrick@kudos.be> - 0.0.8
- Made %postun RPM update aware
* Mon May 08 2017 <patrick@kudos.be> - 0.0.7
- Added check_host_conf.dist
* Sat May 06 2017 <patrick@kudos.be> - 0.0.6
- Added include_core.sh
* Sun Apr 30 2017 <patrick@kudos.be> - 0.0.5
- Added core plugins (mail) and new location of check_health.conf.dist
* Sat Apr 08 2017 <patrick@kudos.be> - 0.0.4
- Changed check_health.conf to check_health.conf.dist and added %post
* Fri Nov 11 2016 <patrick@kudos.be> - 0.0.3
- Added SMS directory
* Sat Nov 05 2016 <patrick@kudos.be> - 0.0.2
- Added mail templates
* Fri Jan 01 2016 <patrick@kudos.be> - 0.0.1
- Initial build
