%define smartmetroot /smartmet

Name:           smartmet-data-hirlam
Version:        17.10.18
Release:        2%{?dist}.fmi
Summary:        SmartMet Data HIRLAM
Group:          System Environment/Base
License:        MIT
URL:            https://github.com/fmidev/smartmet-data-hirlam
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch

Requires:	smartmet-qdtools
Requires:	lbzip2


%description
TODO

%prep

%build

%pre

%install
rm -rf $RPM_BUILD_ROOT
mkdir $RPM_BUILD_ROOT
cd $RPM_BUILD_ROOT

mkdir -p .%{smartmetroot}/cnf/cron/{cron.d,cron.hourly}
mkdir -p .%{smartmetroot}/cnf/data
mkdir -p .%{smartmetroot}/tmp/data
mkdir -p .%{smartmetroot}/logs/data
mkdir -p .%{smartmetroot}/run/data/hirlam/{bin,cnf}

cat > %{buildroot}%{smartmetroot}/cnf/cron/cron.d/hirlam.cron <<EOF
# Run every hour to test if new data is available
# Script will wait new data for maximum of 50 minutes
00 * * * * /smartmet/run/data/hirlam/bin/dohirlamf.sh
EOF

cat > %{buildroot}%{smartmetroot}/cnf/cron/cron.hourly/clean_data_hirlam <<EOF
#!/bin/sh
# Clean HIRLAM data
cleaner -maxfiles 4 '_hirlam_.*_surface.sqd' %{smartmetroot}/data/hirlam
cleaner -maxfiles 4 '_hirlam_.*_pressure.sqd' %{smartmetroot}/data/hirlam
cleaner -maxfiles 4 '_hirlam_.*_surface.sqd' %{smartmetroot}/editor/in
cleaner -maxfiles 4 '_hirlam_.*_pressure.sqd' %{smartmetroot}/editor/in

# Clean incoming HIRLAM data older than 1 day (1 * 24 * 60 = 1440 min)
find /smartmet/data/incoming/hirlam -type f -mmin +1440 -delete
EOF

cat > %{buildroot}%{smartmetroot}/run/data/hirlam/cnf/hirlam-surface.st <<EOF
var x = par49 - AVGT(-1, -1, par49)
par49 = x

par354 = par50 / 3
EOF

cat > %{buildroot}%{smartmetroot}/cnf/data/hirlam.cnf <<EOF
AREA="europe"
EOF

install -m 755 %_topdir/SOURCES/smartmet-data-hirlam/dohirlam.sh %{buildroot}%{smartmetroot}/run/data/hirlam/bin/
install -m 644 %_topdir/SOURCES/smartmet-data-hirlam/hirlam-sfc.conf %{buildroot}%{smartmetroot}/run/data/hirlam/cnf/
install -m 644 %_topdir/SOURCES/smartmet-data-hirlam/hirlam-pl.conf %{buildroot}%{smartmetroot}/run/data/hirlam/cnf/
install -m 644 %_topdir/SOURCES/smartmet-data-hirlam/hirlam-ml.conf %{buildroot}%{smartmetroot}/run/data/hirlam/cnf/

%post

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,smartmet,smartmet,-)
%config(noreplace) %{smartmetroot}/cnf/data/hirlam.cnf
%config(noreplace) %{smartmetroot}/cnf/cron/cron.d/hirlam.cron
%config(noreplace) %{smartmetroot}/run/data/hirlam/cnf/hirlam-sfc.conf
%config(noreplace) %{smartmetroot}/run/data/hirlam/cnf/hirlam-pl.conf
%config(noreplace) %{smartmetroot}/run/data/hirlam/cnf/hirlam-ml.conf
%config(noreplace) %attr(0755,smartmet,smartmet) %{smartmetroot}/cnf/cron/cron.hourly/clean_data_hirlam
%{smartmetroot}/*

%changelog
* Wed Oct 18 2017 Mikko Rauhala <mikko.rauhala@fmi.fi> 17.10.18-1.el7.fmi
- Initial version
