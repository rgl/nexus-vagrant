#!/bin/bash
set -euxo pipefail

nexus_domain=$(hostname --fqdn)

. /vagrant/provision/nexus-groovy.sh

mkdir -p tmp/use-nuget-repository && cd tmp/use-nuget-repository

#
# test the NuGet repository.
# see https://help.sonatype.com/repomanager3/formats/nuget-repositories
# see https://help.sonatype.com/repomanager3/formats/nuget-repositories/grouping-nuget-repositories

# install the dotnet core sdk.
if ! which dotnet; then
  bash -eux /vagrant/provision/provision-dotnet-core-sdk.sh
fi

nuget_source_url=https://$nexus_domain/repository/nuget-group/index.json
nuget_source_push_url=https://$nexus_domain/repository/nuget-hosted/
nuget_source_push_api_key=$(nexus-groovy get-jenkins-nuget-api-key | jq -r '.result | fromjson | .apiKey')
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
cat >example-hello-world.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netcoreapp3.1</TargetFramework>
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
    <PackageReference Include="Serilog" Version="2.10.0" />
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
    <TargetFramework>netcoreapp3.1</TargetFramework>
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
dotnet add package Serilog.Sinks.Console --version 3.1.1
dotnet build -v=n -c=Release
dotnet publish -v=n -c=Release --no-build --output dist
./dist/test
popd
