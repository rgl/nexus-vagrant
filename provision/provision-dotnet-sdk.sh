#!/bin/bash
set -euxo pipefail

# opt-out of telemetry.
echo 'export DOTNET_CLI_TELEMETRY_OPTOUT=1' >/etc/profile.d/opt-out-dotnet-cli-telemetry.sh
source /etc/profile.d/opt-out-dotnet-cli-telemetry.sh

# install the dotnet core sdk.
# see https://docs.microsoft.com/en-us/dotnet/core/install/linux-ubuntu
wget -qO packages-microsoft-prod.deb "https://packages.microsoft.com/config/ubuntu/$(lsb_release -s -r)/packages-microsoft-prod.deb"
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get install -y apt-transport-https
apt-get update
apt-get install -y dotnet-sdk-6.0

# show versions.
dotnet --info
