%define build_timestamp %(date +"%Y%m%d")

Name:           hc-kudos
Version:        %{build_timestamp}
Release:        1

Summary:        The KUDOS Health Checker (HC) for UNIX (KUDOS plugins)
Group:          Tools/Monitoring

License:        GNU General Public License either version 2 of the License, or (at your option) any later version
URL:            http://www.kudos.be

Requires:       ksh,hc-linux
BuildArch:      noarch
BuildRoot:      %{_topdir}/%{name}-%{version}-root
      
%description 
The Health Checker is collection of scripts (plugins) designed to perform regular - but not intensive - health checks on UNIX/Linux systems. It provides plugins for AIX, HP-UX and Linux as well customer specific checks. Checks may include topics such file system mounts, process checks, file consistency etc.
This package contains the KUDOS specific plugins.

%prep

%build

%install
rm -rf $RPM_BUILD_ROOT
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/customer
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/customer/kudos
cp ../SOURCES/lib/customer/kudos/check_kudos_kapow_credits.sh $RPM_BUILD_ROOT/opt/hc/lib/customer/kudos/check_kudos_kapow_credits.sh
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc
cp ../SOURCES/etc/check_kudos_kapow_credits.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_kudos_kapow_credits.conf.dist


%post
# ------------------------- CONFIGURATION starts here -------------------------
# location of check_health.sh
HC_BIN="/opt/hc/bin/check_health.sh"
PATH="$PATH:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin"
# ------------------------- CONFIGURATION ends here ---------------------------
echo "INFO: starting post-install script ..."
# refresh symbolic FPATH links
if [[ -x ${HC_BIN} ]]
then
    ${HC_BIN} --fix-symlinks
    (( $? == 0 )) || echo "WARN: updating symlinks failed"
fi
echo "INFO: finished post-install script"

%postun
# ------------------------- CONFIGURATION starts here -------------------------
# location of check_health.sh
HC_BIN="/opt/hc/bin/check_health.sh"
PATH="$PATH:/usr/bin:/etc:/usr/sbin:/usr/ucb:/usr/bin/X11:/sbin"
# ------------------------- CONFIGURATION ends here ---------------------------
echo "INFO: starting post-install script ..."
# refresh symbolic FPATH links
if [[ -x ${HC_BIN} ]]
then
    ${HC_BIN} --fix-symlinks
    (( $? == 0 )) || echo "WARN: updating symlinks failed"
fi
echo "INFO: finished post-install script"

%files
%defattr(-,root,root,755)
%dir /opt/hc/lib
%dir /opt/hc/lib/customer
%dir /opt/hc/lib/customer/kudos
%attr(755, root, root) /opt/hc/lib/customer/kudos/check_kudos_kapow_credits.sh
%dir /etc/opt/hc
%attr(644, root, root) /etc/opt/hc/check_kudos_kapow_credits.conf.dist

%changelog
* Fri Nov 11 2016 <patrick@kudos.be> - 0.0.1
- Initial build
