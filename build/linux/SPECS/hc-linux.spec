%define build_timestamp %(date +"%Y%m%d")

Name:           hc-linux
Version:        %{build_timestamp}
Release:        1

Summary:        The KUDOS Health Checker (HC) for UNIX
Group:          Tools/Monitoring

License:        GNU General Public License either version 2 of the License, or (at your option) any later version
URL:            http://www.kudos.be

Requires:       ksh,logrotate
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
cp ../SOURCES/opt/hc/bin/check_health.sh $RPM_BUILD_ROOT/opt/hc/bin
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/opt/hc/lib/core/include_core.sh $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/opt/hc/lib/core/include_data.sh $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/opt/hc/lib/core/include_os.sh $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/opt/hc/lib/core/notify_mail.sh $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/opt/hc/lib/core/report_std.sh $RPM_BUILD_ROOT/opt/hc/lib/core
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc
cp ../SOURCES/etc/opt/hc/check_host.conf.dist $RPM_BUILD_ROOT/etc/opt/hc
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core
cp ../SOURCES/etc/opt/hc/core/check_health.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/core
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core/providers
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/opt/hc/core/templates/mail_info.tpl $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/opt/hc/core/templates/mail_header.tpl $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/opt/hc/core/templates/mail_body.tpl $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/opt/hc/core/templates/mail_footer.tpl $RPM_BUILD_ROOT/etc/opt/hc/core/templates
install -d -m 755 $RPM_BUILD_ROOT/var/opt/hc
install -d -m 755 $RPM_BUILD_ROOT/etc/logrotate.d
cp ../SOURCES/etc/logrotate.d/check_health $RPM_BUILD_ROOT/etc/logrotate.d/check_health

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
# set SELinux contexts for logrotate
SESTATUS_BIN=$(command -v sestatus 2>/dev/null)
if [[ -n "${SESTATUS_BIN}" ]]
then
    IS_ENFORCING=$(${SESTATUS_BIN} | grep -c "Current mode.*enforcing" 2>/dev/null)
    if (( IS_ENFORCING > 0 ))
    then
        SEMANAGE_BIN=$(command -v semanage 2>/dev/null)
        if [[ -n "${SEMANAGE_BIN}" ]]
        then
            ${SEMANAGE_BIN} fcontext -a -t var_log_t "${HC_VAR_DIR}(/check_health\.sh\.log.*)?"
            echo "INFO: SELinux fcontexts configured for log rotation"
            if [[ -d ${HC_VAR_DIR} ]]
            then
                RESTORECON_BIN=$(command -v restorecon 2>/dev/null)
                if [[ -n "${RESTORECON_BIN}" ]]
                then
                    ${RESTORECON_BIN} -Frv ${HC_VAR_DIR}
                    echo "INFO: SELinux fcontexts set on ${HC_VAR_DIR} for log rotation"
                else
                    echo "WARN: SELinux is set to 'enforcing' but could not found 'restorecon' to set fcontexts for log rotation"
                fi
            fi
        else
            echo "WARN: SELinux is set to 'enforcing' but could not found 'semanage' to set fcontexts for log rotation"
        fi
    fi
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
%attr(755, root, root) /opt/hc/lib/core/report_std.sh
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
%dir /etc/logrotate.d
%attr(644, root, root) /etc/logrotate.d/check_health

%changelog
* Tue Mar 26 2019 <patrick@kudos.be> - 0.2.0
- New git tree organization
* Sat Nov 10 2018 <patrick@kudos.be> - 0.1.0
- Added logrotate file
* Mon Dec 18 2017 <patrick@kudos.be> - 0.0.9
- Added report_std.sh
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
