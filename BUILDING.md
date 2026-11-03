# Building KmyTarkovApi against a local SPT installation

The projects are legacy (non-SDK) .NET Framework 4.7.2 class libraries. They are
compiled against the managed assemblies of the game client and BepInEx, both of
which ship with SPT — nothing is redistributed with this repository.

## Requirements

* Windows with MSBuild (Visual Studio 2022 Build Tools, workload
  `.NET desktop build tools`, plus the .NET Framework 4.7.2 targeting pack)
* SPT installation with BepInEx 5 (client 0.16.9.x / SPT 4.1.x is what the
  current sources target)
* `nuget.exe` for restoring the `packages.config` files

## Path configuration

`Directory.Build.props` defines where the game assemblies are taken from:

```xml
<SPTGamePath Condition="'$(SPTGamePath)' == ''">D:\Games\SPT 4.1.6 essential</SPTGamePath>
<SptManagedDir>$(SPTGamePath)\EscapeFromTarkov_Data\Managed</SptManagedDir>
<SptBepInExCoreDir>$(SPTGamePath)\BepInEx\core</SptBepInExCoreDir>
```

Either change the default or override it per build:

```
msbuild KmyTarkovApi.sln /p:SPTGamePath="D:\Games\SPT 4.1.6 essential"
```

## Signing

The strong-name key `kmyuhkyuk.pfx` is not part of the repository. When it is
missing next to a project file, `Directory.Build.targets` sets
`SignAssembly=false`, so an unsigned build works out of the box. Drop the real
key into the project folders to get signed assemblies again.

## Build

```
nuget restore KmyTarkovApi.sln -PackagesDirectory packages
msbuild KmyTarkovApi.sln /p:Configuration=Release /p:Platform=AnyCPU
```

or simply

```
powershell -ExecutionPolicy Bypass -File build-spt.ps1
```

`Build/Build.csproj` (the release packer) is not part of this flow: it expects
the author's own checkout, 7-Zip and LibGit2Sharp and copies to hardcoded
paths. `build-spt.ps1` copies the resulting plugins instead.

## AssetBundle

`KmyTarkovConfiguration` loads `bundles\kmytarkovconfiguration.bundle` from the
plugin folder. That bundle is built from the author's Unity project and is **not**
part of the repository, so it has to be taken from an official release archive
(`BepInEx/plugins/kmyuhkyuk-KmyTarkovApi/bundles/`) and placed next to the built
DLLs. Without it the API still loads, but the in-game configuration UI fails with
`EFTConfigurationModel: Failed to load AssetBundle!`.

## Installing

Copy the plugin folder to `BepInEx\plugins\kmyuhkyuk-KmyTarkovApi`:

```
KmyTarkovApi.dll
KmyTarkovUtils.dll
KmyTarkovReflection.dll
KmyTarkovConfiguration.dll
ConfigurationTest.dll
HtmlAgilityPack.dll
Crc32.NET.dll
bundles\kmytarkovconfiguration.bundle
localized\en.json, localized\zh.json
```

`Newtonsoft.Json` comes from the game installation and is deliberately not copied.
