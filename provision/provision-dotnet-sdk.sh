#!/bin/bash
set -euxo pipefail

# opt-out of telemetry.
echo 'export DOTNET_CLI_TELEMETRY_OPTOUT=1' >/etc/profile.d/opt-out-dotnet-cli-telemetry.sh
source /etc/profile.d/opt-out-dotnet-cli-telemetry.sh

# pin the microsoft apt repository packages above the distro ones.
# see apt-cache policy
# see apt-cache policy dotnet-sdk-8.0
# see apt-cache showpkg dotnet-sdk-8.0
# see http://manpages.ubuntu.com/manpages/jammy/en/man5/apt_preferences.5.html
cat >/etc/apt/preferences.d/packages.microsoft.com.pref <<'EOF'
Package: *
Pin: origin "packages.microsoft.com"
Pin-Priority: 999
EOF

# install the dotnet core sdk.
# see https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu
wget -qO packages-microsoft-prod.deb "https://packages.microsoft.com/config/ubuntu/$(lsb_release -s -r)/packages-microsoft-prod.deb"
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get install -y apt-transport-https
apt-get update
apt-get install -y dotnet-sdk-8.0

# show versions.
dotnet --info
