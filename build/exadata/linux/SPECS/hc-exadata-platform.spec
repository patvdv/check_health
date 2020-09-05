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
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/core
cp ../SOURCES/opt/hc/lib/core/include_exadata.sh $RPM_BUILD_ROOT/opt/hc/lib/core
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/platform
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_cell_alerts.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_cell_alerts.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_cell_celldisks.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_cell_celldisks.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_cell_flash.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_cell_flash.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_cell_griddisks.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_cell_griddisks.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_cell_luns.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_cell_luns.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_cell_megaraid.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_cell_megaraid.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_cell_physicaldisks.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_cell_physicaldisks.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_ib_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_ib_status.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_megaraid.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_megaraid.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_cluster.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_cluster.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_logs.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_logs.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_pool_usage.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_pool_usage.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_services.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_services.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_share_replication.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_share_replication.sh
cp ../SOURCES/opt/hc/lib/platform/exadata/check_exadata_zfs_share_usage.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/exadata/check_exadata_zfs_share_usage.sh

install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc
cp ../SOURCES/etc/opt/hc/check_exadata_cell_alerts.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_cell_alerts.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_cell_celldisks.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_cell_celldisks.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_cell_flash.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_cell_flash.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_cell_griddisks.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_cell_griddisks.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_cell_luns.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_cell_luns.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_cell_megaraid.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_cell_megaraid.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_cell_physicaldisks.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_cell_physicaldisks.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_megaraid.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_megaraid.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_zfs_cluster.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_zfs_cluster.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_zfs_logs.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_zfs_logs.conf.dist
cp ../SOURCES/etc/opt/hc/check_exadata_zfs_pool_usage.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_exadata_zfs_pool_usage.conf.dist
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
%dir /opt/hc/lib/core
%attr(755, root, root) /opt/hc/lib/core/include_exadata.sh
%dir /opt/hc/lib/platform
%dir /opt/hc/lib/platform/exadata
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_cell_alerts.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_cell_celldisks.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_cell_flash.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_cell_griddisks.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_cell_luns.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_cell_megaraid.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_cell_physicaldisks.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_ib_status.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_megaraid.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_cluster.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_logs.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_pool_usage.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_services.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_share_replication.sh
%attr(755, root, root) /opt/hc/lib/platform/exadata/check_exadata_zfs_share_usage.sh
%dir /etc/opt/hc
%attr(644, root, root) /etc/opt/hc/check_exadata_cell_alerts.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_cell_celldisks.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_cell_flash.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_cell_griddisks.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_cell_luns.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_cell_megaraid.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_cell_physicaldisks.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_megaraid.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_cluster.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_logs.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_pool_usage.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_services.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_share_replication.conf.dist
%attr(644, root, root) /etc/opt/hc/check_exadata_zfs_share_usage.conf.dist


%changelog
* Tue Jul 07 2020 <patrick@kudos.be> - 0.5.0
- Added check_exadata_ib_status
* Fri Jul 07 2019 <patrick@kudos.be> - 0.4.0
- Added check_exadata_zfs_cluster
* Fri May 14 2019 <patrick@kudos.be> - 0.3.0
- Added include_exadata
- Added plugin check_exadata_cell_alerts
- Added plugin check_exadata_cell_celldisks
- Added plugin check_exadata_cell_flash
- Added plugin check_exadata_cell_griddisks
- Added plugin check_exadata_cell_luns
- Added plugin check_exadata_cell_megaraid
- Added plugin check_exadata_cell_physicaldisks
- Added plugin check_exadata_megaraid
* Fri Apr 12 2019 <patrick@kudos.be> - 0.2.0
- Added plugin check_exadata_zfs_pool_usage
* Tue Mar 26 2019 <patrick@kudos.be> - 0.1.0
- New git tree organization
* Mon Feb 18 2019 <patrick@kudos.be> - 0.0.1
- Initial build
