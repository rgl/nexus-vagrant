#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

# see the requests made when using https://nexus.example.com/#user/nugetapitoken UI.
function get-jenkins-nuget-api-key {
  local username='jenkins'
  local password='password'
  local user_token=$(http \
    -a "$username:$password" \
    --ignore-stdin \
    --check-status \
    POST https://$nexus_domain/service/extdirect \
    action=rapture_Security \
    method=authenticationToken \
    type=rpc \
    tid:=0 \
    data:="[\"$(echo -n "$username" | base64 -w0)\",\"$(echo -n "$password" | base64 -w0)\"]" \
    | jq -r .result.data)
  http \
    -a "$username:$password" \
    --ignore-stdin \
    --check-status \
    GET https://$nexus_domain/service/rest/internal/nuget-api-key \
    authToken=="$(echo -n "$user_token" | base64 -w0)" \
    | jq -r .apiKey
}

mkdir -p tmp/use-nuget-repository && cd tmp/use-nuget-repository

#
# test the NuGet repository.
# see https://help.sonatype.com/en/nuget-repositories.html

# install the dotnet sdk.
if ! which dotnet; then
  bash -eux /vagrant/provision/provision-dotnet-sdk.sh
fi

nuget_source_url=https://$nexus_domain/repository/nuget-group/index.json
nuget_source_push_url=https://$nexus_domain/repository/nuget-hosted/
nuget_source_push_api_key=$(get-jenkins-nuget-api-key)
echo -n $nuget_source_push_api_key >/vagrant/shared/jenkins-nuget-api-key
nuget_source_push_api_key="$(cat /vagrant/shared/jenkins-nuget-api-key)"

# configure the project nuget package sources to use nexus.
# NB the projects inside the current directory (and childs) inherit
#    this nuget configuration.
# see https://docs.microsoft.com/en-us/nuget/reference/nuget-config-file
cat >nuget.config <<EOF
<configuration>
  <packageSources>
    <clear />
    <add key="$nexus_domain" value="$nuget_source_url" />
  </packageSources>
</configuration>
EOF

# show the package sources.
dotnet nuget list source

# create the example project.
# see https://docs.microsoft.com/en-us/nuget/reference/msbuild-targets#packing-using-a-nuspec
# see https://docs.microsoft.com/en-us/nuget/reference/msbuild-targets#pack-target
# see https://www.nuget.org/packages/Serilog/
# renovate: datasource=nuget depName=Serilog
serilog_version='4.3.0'
cat >example-hello-world.csproj <<EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Version>1.0.0</Version>
    <Authors>Alice Doe</Authors>
    <Copyright>Copyleft Alice Doe</Copyright>
    <Description>Example Package Description</Description>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
    <PackageProjectUrl>http://example.com</PackageProjectUrl>
    <PackageReleaseNotes>Example Release Notes.</PackageReleaseNotes>
    <PackageTags>example tags</PackageTags>
    <NuspecProperties>
      owners=Bob Doe
    </NuspecProperties>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Serilog" Version="$serilog_version" />
  </ItemGroup>
</Project>
EOF
cat >Greeter.cs <<'EOF'
namespace Example
{
  using Serilog;

  public class Greeter
  {
    private static readonly ILogger Logger = Log.ForContext<Greeter>();

    public static string Greet(string name)
    {
      Logger.Information("Creating greet for {name}", name);

      return $"Hello {name}!";
    }
  }
}
EOF

# restore package and build the project.
dotnet build -v=n -c=Release

# package it into a nuget/nupkg package.
dotnet pack -v=n -c=Release --no-build --output .

# show the resulting package files and the nuspec.
unzip -l example-hello-world.1.0.0.nupkg
unzip -c example-hello-world.1.0.0.nupkg example-hello-world.nuspec

# publish the package to nexus.
dotnet nuget push \
  example-hello-world.1.0.0.nupkg \
  --source $nuget_source_push_url \
  --api-key $nuget_source_push_api_key

# test its usage from a test application.
rm -rf test && mkdir test && pushd test
cat >test.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
EOF
cat >Program.cs <<'EOF'
namespace Example
{
  using System;
  using Serilog;

  public class Program
  {
    public static void Main()
    {
      Log.Logger = new LoggerConfiguration()
        .MinimumLevel.Debug()
        .Enrich.WithProperty("Application", "example")
        .Enrich.FromLogContext()
        .WriteTo.Console(
          outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Properties:j} {Message:lj}{NewLine}{Exception}")
        .CreateLogger();

      Console.WriteLine(Greeter.Greet("Rui"));

      Log.CloseAndFlush();
    }
  }
}
EOF
dotnet nuget list source
dotnet add package example-hello-world
# see https://www.nuget.org/packages/Serilog.Sinks.Console/
# renovate: datasource=nuget depName=Serilog.Sinks.Console
serilog_sinks_console_version='6.0.0'
dotnet add package Serilog.Sinks.Console --version "$serilog_sinks_console_version"
dotnet build -v=n -c=Release
dotnet publish -v=n -c=Release --no-build --output dist
./dist/test
popd
