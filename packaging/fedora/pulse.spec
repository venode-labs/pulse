Name:           pulse-sec
Version:        0.3.0
Release:        1%{?dist}
Summary:        Host security pulse-check, CLI + KDE Plasma widget

License:        MIT
URL:            https://github.com/keletonik/pulse
Source0:        https://github.com/keletonik/pulse/archive/v%{version}/pulse-%{version}.tar.gz

BuildArch:      noarch
Requires:       bash
Requires:       jq
Requires:       curl
Requires:       iproute
Requires:       systemd
Recommends:     kdialog

%description
Composite risk score from fourteen host probes (firewall, kernel age,
listening ports, LUKS, SSH, secure boot, suid drift and others)
cross-referenced against CVE feeds (Arch ALSA, CISA KEV, NVD, EPSS).

Pulse is Arch-first. On Fedora the package-inventory probe is a no-op
until a dnf backend lands in v1.x; the host-hardening probes still
work and give a useful score.

%package -n pulse-plasmoid
Summary:        KDE Plasma 6 widget for pulse
Requires:       pulse-sec = %{version}-%{release}
Requires:       plasma-workspace
BuildArch:      noarch

%description -n pulse-plasmoid
Plasma 6 widget that renders the pulse composite score, probe rows
and CVE list. Reads JSON state written by pulse-collector.

%prep
%autosetup -n pulse-%{version}

%install
install -Dm0755 bin/pulse           %{buildroot}%{_bindir}/pulse
install -Dm0755 bin/pulse-collector %{buildroot}%{_bindir}/pulse-collector

install -Dm0644 systemd/pulse.service %{buildroot}%{_userunitdir}/pulse.service
install -Dm0644 systemd/pulse.timer   %{buildroot}%{_userunitdir}/pulse.timer

install -Dm0644 config/config.toml.example %{buildroot}%{_sysconfdir}/pulse/config.toml
install -Dm0644 config/pulse.conf          %{buildroot}%{_prefix}/lib/environment.d/90-pulse.conf

install -Dm0644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE

# Plasmoid lands in the -plasmoid subpackage
install -d %{buildroot}%{_datadir}/plasma/plasmoids/com.casper.pulse
cp -r plasmoid/com.casper.pulse/. %{buildroot}%{_datadir}/plasma/plasmoids/com.casper.pulse/

%files
%license LICENSE
%doc README.md
%config(noreplace) %{_sysconfdir}/pulse/config.toml
%{_bindir}/pulse
%{_bindir}/pulse-collector
%{_userunitdir}/pulse.service
%{_userunitdir}/pulse.timer
%{_prefix}/lib/environment.d/90-pulse.conf

%files -n pulse-plasmoid
%{_datadir}/plasma/plasmoids/com.casper.pulse

%changelog
* Sun May 24 2026 Venode Labs <labs@venode.ai> - 0.3.0-1
- Initial public release.
