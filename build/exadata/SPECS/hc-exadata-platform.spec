%define build_timestamp %(date +"%Y%m%d")

Name:           hc-exadata-platform
Version:        %{build_timestamp}
Release:        1

Summary:        The KUDOS Health Checker (HC) for UNIX (Exadata platform plugins)
Group:          Tools/Monitoring

License:        GNU General Public License either version 2 of the License, or (at your option) any later version
URL:            http://www.kudos.be

Requires:       ksh,hc-linux
BuildArch:      noarch
BuildRoot:      %{_topdir}/%{name}-%{version}-root

%description
The Health Checker is collection of scripts (plugins) designed to perform regular - but not intensive - health checks on UNIX/Linux systems. It provides plugins for AIX, HP-UX and Linux as well customer specific checks. Checks may include topics such file system mounts, process checks, file consistency etc.
This package contains platform/OS specific plugins.

%prep

%build

%install
rm -rf $RPM_BUILD_ROOT
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/platform
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_logs.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_logs.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_services.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_services.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_share_replication.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_share_replication.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_share_usage.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_share_usage.sh

install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc
cp ../SOURCES/etc/opt/hc/check_exadata_zfs_logs.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_zfs_logs.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_zfs_services.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_zfs_services.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_zfs_share_replication.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_zfs_share_replication.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_zfs_share_usage.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_zfs_share_usage.conf.dist


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
%dir /opt/hc/lib/platform/exadata
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_logs.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_services.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_share_replication.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_share_usage.sh
%dir /etc/opt/hc
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_logs.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_services.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_share_replication.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_share_usage.conf.dist


%changelog
* Tue Mar 26 2019 <patrick@kudos.be> - 0.1.0
- New git tree organization
* Mon Feb 18 2019 <patrick@kudos.be> - 0.0.1
- Initial build
