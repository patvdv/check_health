%define build_timestamp %(date +"%Y%m%d")

Name:           hc-serviceguard-platform
Version:        %{build_timestamp}
Release:        1

Summary:        The KUDOS Health Checker (HC) for UNIX (Serviceguard plugins)
Group:          Tools/Monitoring

License:        GNU General Public License either version 2 of the License, or (at your option) any later version
URL:            http://www.kudos.be

Requires:       ksh,hc-linux
BuildArch:      noarch
BuildRoot:      %{_topdir}/%{name}-%{version}-root

%description
The Health Checker is collection of scripts (plugins) designed to perform regular - but not intensive - health checks on UNIX/Linux systems. It provides plugins for AIX, HP-UX and Linux as well customer specific checks. Checks may include topics such file system mounts, process checks, file consistency etc.
This package contains Serviceguard platform specific plugins.

%prep

%build

%install
rm -rf $RPM_BUILD_ROOT
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/platform
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/platform/serviceguard
cp ../SOURCES/opt/hc/lib/platform/serviceguard/check_serviceguard_cluster_config.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/serviceguard/check_serviceguard_cluster_config.sh
cp ../SOURCES/opt/hc/lib/platform/serviceguard/check_serviceguard_cluster_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/serviceguard/check_serviceguard_cluster_status.sh
cp ../SOURCES/opt/hc/lib/platform/serviceguard/check_serviceguard_package_config.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/serviceguard/check_serviceguard_package_config.sh
cp ../SOURCES/opt/hc/lib/platform/serviceguard/check_serviceguard_package_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/serviceguard/check_serviceguard_package_status.sh
cp ../SOURCES/opt/hc/lib/platform/serviceguard/check_serviceguard_qs_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/serviceguard/check_serviceguard_qs_status.sh
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc
cp ../SOURCES/etc/opt/hc/check_serviceguard_cluster_config.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_serviceguard_cluster_config.conf.dist
cp ../SOURCES/etc/opt/hc/check_serviceguard_cluster_status.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_serviceguard_cluster_status.conf.dist
cp ../SOURCES/etc/opt/hc/check_serviceguard_package_config.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_serviceguard_package_config.conf.dist
cp ../SOURCES/etc/opt/hc/check_serviceguard_package_status.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_serviceguard_package_status.conf.dist
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
echo "INFO: starting post-uninstall script ..."
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
%dir /opt/hc/lib/platform
%dir /opt/hc/lib/platform/serviceguard
%attr(755, root, root) /opt/hc/lib/platform/serviceguard/check_serviceguard_cluster_config.sh
%attr(755, root, root) /opt/hc/lib/platform/serviceguard/check_serviceguard_cluster_status.sh
%attr(755, root, root) /opt/hc/lib/platform/serviceguard/check_serviceguard_package_config.sh
%attr(755, root, root) /opt/hc/lib/platform/serviceguard/check_serviceguard_package_status.sh
%attr(755, root, root) /opt/hc/lib/platform/serviceguard/check_serviceguard_qs_status.sh
%dir /etc/opt/hc
%attr(644, root, root) /etc/opt/hc/check_serviceguard_cluster_config.conf.dist
%attr(644, root, root) /etc/opt/hc/check_serviceguard_cluster_status.conf.dist
%attr(644, root, root) /etc/opt/hc/check_serviceguard_package_config.conf.dist
%attr(644, root, root) /etc/opt/hc/check_serviceguard_package_status.conf.dist
%dir /etc/opt/hc/core
%dir /etc/opt/hc/core/templates

%changelog
* Sa Apr 20 2019 <patrick@kudos.be> - 0.0.1
- Initial build
