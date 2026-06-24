#!/bin/bash
set -euxo pipefail

# opt-out of telemetry.
echo 'export DOTNET_CLI_TELEMETRY_OPTOUT=1' >/etc/profile.d/opt-out-dotnet-cli-telemetry.sh
source /etc/profile.d/opt-out-dotnet-cli-telemetry.sh

# install the dotnet sdk.
apt-get install -y dotnet-sdk-10.0

# show versions.
dotnet --info
