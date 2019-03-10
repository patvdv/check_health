%define build_timestamp %(date +"%Y%m%d")

Name:           hc-linux-platform
Version:        %{build_timestamp}
Release:        1

Summary:        The KUDOS Health Checker (HC) for UNIX (platform plugins)
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
install -d -m 755 $RPM_BUILD_ROOT/opt/hc/lib/platform/linux
cp ../SOURCES/lib/platform/linux/check_linux_burp_backup.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_burp_backup.sh
cp ../SOURCES/lib/platform/linux/check_linux_burp_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_burp_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_es_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_es_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_file_age.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_file_age.sh
cp ../SOURCES/lib/platform/linux/check_linux_file_change.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_file_change.sh
cp ../SOURCES/lib/platform/linux/check_linux_fs_mounts.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_fs_mounts.sh
cp ../SOURCES/lib/platform/linux/check_linux_fs_usage.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_fs_usage.sh
cp ../SOURCES/lib/platform/linux/check_linux_httpd_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_httpd_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_mysqld_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_mysqld_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_named_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_named_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_ntp_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_ntp_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_postfix_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_postfix_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_samba_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_samba_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_shorewall_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_shorewall_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_sshd_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_sshd_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_winbind_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_winbind_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_hpasmcli.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_hpasmcli.sh
cp ../SOURCES/lib/platform/linux/check_linux_hpacucli.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_hpacucli.sh
cp ../SOURCES/lib/platform/linux/check_linux_hplog.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_hplog.sh
cp ../SOURCES/lib/platform/linux/check_linux_hpssacli.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_hpssacli.sh
cp ../SOURCES/lib/platform/linux/check_linux_process_limits.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_process_limits.sh
cp ../SOURCES/lib/platform/linux/check_linux_root_crontab.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_root_crontab.sh
cp ../SOURCES/lib/platform/linux/check_linux_sg_cluster_config.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_sg_cluster_config.sh
cp ../SOURCES/lib/platform/linux/check_linux_sg_cluster_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_sg_cluster_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_sg_package_config.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_sg_package_config.sh
cp ../SOURCES/lib/platform/linux/check_linux_sg_package_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_sg_package_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_sg_qs_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_sg_qs_status.sh
cp ../SOURCES/lib/platform/linux/check_linux_vz_ct_counters.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_vz_ct_counters.sh
cp ../SOURCES/lib/platform/linux/check_linux_vz_ct_status.sh $RPM_BUILD_ROOT/opt/hc/lib/platform/linux/check_linux_vz_ct_status.sh
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc
cp ../SOURCES/etc/check_linux_burp_backup.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_burp_backup.conf.dist
cp ../SOURCES/etc/check_linux_es_status.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_es_status.conf.dist
cp ../SOURCES/etc/check_linux_file_age.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_file_age.conf.dist
cp ../SOURCES/etc/check_linux_file_change.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_file_change.conf.dist
cp ../SOURCES/etc/check_linux_fs_usage.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_fs_usage.conf.dist
cp ../SOURCES/etc/check_linux_hpasmcli.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_hpasmcli.conf.dist
cp ../SOURCES/etc/check_linux_hpacucli.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_hpacucli.conf.dist
cp ../SOURCES/etc/check_linux_hplog.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_hplog.conf.dist
cp ../SOURCES/etc/check_linux_hpssacli.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_hpssacli.conf.dist
cp ../SOURCES/etc/check_linux_mysqld_status.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_mysqld_status.conf.dist
cp ../SOURCES/etc/check_linux_ntp_status.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_ntp_status.conf.dist
cp ../SOURCES/etc/check_linux_process_limits.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_process_limits.conf.dist
cp ../SOURCES/etc/check_linux_root_crontab.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_root_crontab.conf.dist
cp ../SOURCES/etc/check_linux_sg_cluster_config.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_sg_cluster_config.conf.dist
cp ../SOURCES/etc/check_linux_sg_cluster_status.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_sg_cluster_status.conf.dist
cp ../SOURCES/etc/check_linux_sg_package_config.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_sg_package_config.conf.dist
cp ../SOURCES/etc/check_linux_sg_package_status.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_sg_package_status.conf.dist
cp ../SOURCES/etc/check_linux_vz_ct_counters.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_vz_ct_counters.conf.dist
cp ../SOURCES/etc/check_linux_vz_ct_status.conf.dist $RPM_BUILD_ROOT/etc/opt/hc/check_linux_vz_ct_status.conf.dist
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core
install -d -m 755 $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/core/templates/mail_body.tpl-check_linux_fs_mounts_options $RPM_BUILD_ROOT/etc/opt/hc/core/templates
cp ../SOURCES/etc/core/templates/mail_body.tpl-check_linux_root_crontab $RPM_BUILD_ROOT/etc/opt/hc/core/templates

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
%dir /opt/hc/lib/platform/linux
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_burp_backup.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_burp_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_es_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_file_age.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_file_change.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_fs_mounts.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_fs_usage.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_httpd_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_mysqld_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_named_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_ntp_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_postfix_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_samba_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_shorewall_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_sshd_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_winbind_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_hpasmcli.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_hpacucli.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_hplog.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_hpssacli.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_process_limits.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_root_crontab.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_sg_cluster_config.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_sg_cluster_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_sg_package_config.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_sg_package_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_sg_qs_status.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_vz_ct_counters.sh
%attr(755, root, root) /opt/hc/lib/platform/linux/check_linux_vz_ct_status.sh
%dir /etc/opt/hc
%attr(644, root, root) /etc/opt/hc/check_linux_burp_backup.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_es_status.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_file_age.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_file_change.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_fs_usage.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_hpasmcli.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_hpacucli.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_hplog.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_hpssacli.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_mysqld_status.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_ntp_status.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_process_limits.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_root_crontab.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_sg_cluster_config.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_sg_cluster_status.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_sg_package_config.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_sg_package_status.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_vz_ct_counters.conf.dist
%attr(644, root, root) /etc/opt/hc/check_linux_vz_ct_status.conf.dist
%dir /etc/opt/hc/core
%dir /etc/opt/hc/core/templates
%attr(644, root, root) /etc/opt/hc/core/templates/mail_body.tpl-check_linux_fs_mounts_options
%attr(644, root, root) /etc/opt/hc/core/templates/mail_body.tpl-check_linux_root_crontab

%changelog
* Sat Mar 09 2019 <patrick@kudos.be> - 0.1.5
- Added check_linux_es_status
* Sun Feb 10 2019 <patrick@kudos.be> - 0.1.4
- Added check_linux_mysqld_status
* Thu Feb 07 2019 <patrick@kudos.be> - 0.1.3
- Added check_linux_vz_ct_counters
* Tue Jan 22 2019 <patrick@kudos.be> - 0.1.2
- Added check_linux_fs_usage
* Tue Jul 10 2018 <patrick@kudos.be> - 0.1.1
- Added check_linux_process_limits
* Sat Apr 21 2018 <patrick@kudos.be> - 0.1.0
- Added check_linux_ntp_status
* Thu May 18 2017 <patrick@kudos.be> - 0.0.9
- Added check_linux_file_change
* Thu May 04 2017 <patrick@kudos.be> - 0.0.9
- Added check_linux_sg_qs_status
* Sun Apr 30 2017 <patrick@kudos.be> - 0.0.8
- Updated location of templates (../core)
* Sun Apr 23 2017 <patrick@kudos.be> - 0.0.7
- Added httpd check script
* Sat Apr 22 2017 <patrick@kudos.be> - 0.0.6
- Added hplog script
* Thu Apr 06 2017 <patrick@kudos.be> - 0.0.5
- Added hpasmcli + serviceguard scripts
* Sat Apr 01 2017 <patrick@kudos.be> - 0.0.4
- Added openvz container check
* Thu Dec 01 2016 <patrick@kudos.be> - 0.0.3
- Added burp,named,postfix,sshd,shorewall check
* Sat Nov 05 2016 <patrick@kudos.be> - 0.0.2
- Added mail templates
* Fri Jan 01 2016 <patrick@kudos.be> - 0.0.1
- Initial build
