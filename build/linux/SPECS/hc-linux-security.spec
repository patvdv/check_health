%define build_timestamp %(date +"%Y%m%d")

Name:           hc-linux-security
Version:        %{build_timestamp}
Release:        1

Summary:        The KUDOS Health Checker (HC) for UNIX (security plugins)
Group:          Tools/Monitoring

License:        GNU General Public License either version 2 of the License, or (at your option) any later version
URL:            http://www.kudos.be

Requires:       ksh,hc-linux
BuildArch:      noarch
BuildRoot:      %{_topdir}/%{name}-%{version}-root
      
%description 
The Health Checker is collection of scripts (plugins) designed to perform regular - but not intensive - health checks on UNIX/Linux systems. It provides plugins for AIX, HP-UX and Linux as well customer specific checks. Checks may include topics such file system mounts, process checks, file consistency etc.
This package contains security specific plugins.

%prep

%build

%install
rm -rf $RPM_BUILD_ROOT
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/security
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/security
cp ../SOURCES/lib/security/check_all_ssh_controls.sh $RPM_BUILD_ROOT/opt/hc/lib/security/check_all_ssh_controls.sh
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core/templates

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
%dir /opt/hc/lib/security
%attr(755, root, root) /opt/hc/lib/security/check_all_ssh_controls.sh

%changelog
* Fri Jan 01 2016 <patrick@kudos.be> - 0.0.1
- Initial build
