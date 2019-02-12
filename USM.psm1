#!/usr/bin/env pwsh

function get_app_path([string] $app) {
    Join-Path $env:USM_PATH $app
}

function get_current_version([string] $app) {
    $current_path = Join-Path (get_app_path $app) "current"
    Split-Path -Path (Get-Item $current_path).Target -Leaf
}

$environment_script = @'
# Source this file from your PS profile to update your path

<#
Loads the current/bin/ subdirectory of each directory in the given path into the PATH
environment variable.
#>
function populate_path_var([string] $prefix) {
    $path = $env:PATH.Split([IO.Path]::PathSeparator)

    Get-ChildItem $prefix | ForEach-Object {
        $path += Join-Path $_.FullName "current/bin"
    }

    $env:PATH = $path | Join-String -Separator [IO.Path]::PathSeparator
}

<#
Converts a path into a form that can be consistently compared.
#>
function normalize_path([string] $path) {
    if ($IsWindows) {
        $path.ToLower().Replace("\", "/").TrimEnd("/")
    } elseif ($IsOSX) {
        $path.ToLower().Trim("/")
    } else {
        $path.TrimEnd("/")
    }
}

<#
Removes all entires from the PATH environment variable which start with the
given prefix.
#>
function clean_path_var([string] $prefix) {
    $normalized_prefix = normalize_path $prefix

    $path = $env:PATH.Split([IO.Path]::PathSeparator)
    $new_path = $path | Where-Object {
        $normalized_element = normalize_path $_
        !$normalized.StartsWith($normalized_prefix)
    }

    $env:PATH = $new_path | Join-String -Separator [IO.Path]::PathSeparator
}

$env:USM_PATH = "%USM_PATH%"
clean_path_var $env:USM_PATH
populate_path_var $env:USM_PATH

Import-Module USM
Write-Host "Finished loading USM"
'@

<#
.SYNOPSIS
Installs the USM profile script.

.DESCRIPTION
This copies the USM profile script to an appropriate location, and configures
it to assign the value of $env:USM_PATH to a different appropriate directory.

Once this command is run, you should source the profile script in your PS
profile to allow USM to manage your path.

.PARAMETER ProfileDir
Manually sets the location where the profile script will be copied. If not
set, then this will default to ".usm.ps1" under either $env:HOME or (if not
set) $env:HOMEPATH.

.PARAMETER AppsDir
Manually sets the location where the Apps directory will be copied. If not
set, then this will default to the "Apps" directory under either $env:HOME or
(if not set) $env:HOMEPATH.

.PARAMETER Force
By default, if the directory used for $AppsDir already exists, this function
will fail with an error message. To override this error, set this switch.
#>
function Install-USM([string] $ProfileDir = $null, [string] $AppsDir = $null, [switch] $Force = $false) {
    # We should respect this even on Windows, in case someone has set this 
    # manually for Unix tooling
    $preferred_directory = $env:HOME
    if (!$preferred_directory) {
        $preferred_directory = Join-Path $env:HOMEDRIVE $env:HOMEPATH
    }

    if ($ProfileDir) {
        $init_file = Join-Path $BaseDir ".usm.ps1"
    } else {
        $init_file = Join-Path $preferred_directory ".usm.ps1"
    }

    if (!$AppsDir) {
        $AppsDir = Join-Path $preferred_directory "Apps"
    }

    if (Test-Path $AppsDir) {
        if (!$Force) {
            throw "App directory $AppsDir already exists, please use -Force if you wish to install there anyway"
        }
    } else {
        New-Item -Path $AppsDir -ItemType Directory
    }

    Set-Content -Path $init_file -Value $environment_script.Replace("%USM_PATH%", $AppsDir)

    Write-Host "Please configure your PS profile script ($profile) to dot-source $init_file"
    Write-Host "Then, restart your current shell to get access to the USM functions"
}

Export-ModuleMember -Function Install-USM

<#
.SYNOPSIS
Creates a directory for a new version of an application.

.DESCRIPTION
This creates a new directory in $env:USM_PATH for the given application and
version, possibly creating an application directory if this version is the
first.

.PARAMETER App
The name of the application to create.

.PARAMETER Version
The version of the application to create. This cannot be "current" since that
version is reserved for the symbolic link.
#>
function Add-USMApp([string] $App, [string] $Version) {
    if ($Version -eq "current") {
        throw "Version 'current' is restricted, cannot add"
    }

    $target = get_app_path $App
    $new_app = $false

    if (!(Test-Path $target)) {
        New-Item -Path $target -ItemType Directory
        $new_app = $true
    }

    New-Item -Path (Join-Path $target $Version) -ItemType Directory

    if ($new_app) {
        Switch-USMAppVersion -App $App -Version $Version
    }
}

Export-ModuleMember -Function Add-USMApp

<#
.SYNOPSIS
Changes the default version of an application.

.DESCRIPTION
This reassigns the "current" version symbolic link of the given application
to the given version. This immediately affects which version is on your
$env:PATH since $env:PATH always points at the "current" link.

.PARAMETER App
The name of the application to set the current version of.

.PARAMETER Version
The version to set as the current version.
#>
function Switch-USMAppVersion([string] $App, [string] $Version) {
    $target_app = get_app_path $App
    $target_current = Join-Path $target_app "current"
    $target_version = Join-Path $target_app $Version

    if (!(Test-Path $target_app)) {
        throw "App $App does not exist"
    }

    if (!(Test-Path $target_app)) {
        throw "App $App does not have a version $Version"
    }

    if (Test-Path $target_current) {
        Remove-Item $target_current
    }

    New-Item -ItemType SymbolicLink -Path $target_current -Target $target_version
}

Export-ModuleMember -Function Switch-USMAppVersion

<#
.SYNOPSIS
Returns information about applications registered in USM.

.DESCRIPTION
This iterates all the applications and the versions of each application, and
returns an application object for each version. The application object has
these fields:

- [string] App: The application this version belongs to.
- [boolean] IsCurrent: Whether this version is currently the current version.
- [string] Version: The name of the version.

Note that the "current" version is never returned in this listing.

.PARAMETER App
The name of the application to set the current version of.

.PARAMETER Version
The version to set as the current version. Cannot be "current" since that
version name is reserved.
#>
function Get-USMApp([string] $App = $null, [string] $Version = $null) {
    if ($Version -eq "current") {
        throw "The 'current' version is never returned by Get-USMApp"
    }

    Get-ChildItem $env:USM_PATH `
    | ForEach-Object {
        $current_version = get_current_version $_.Name

        $app_directory = $_
        $app_directory `
            | Get-ChildItem `
            | Where-Object { 
                $_.Name -ne "current"
            } | ForEach-Object {
                $is_current = $_.Name -eq $current_version
                New-Object PSObject -Property @{
                    App=$app_directory.Name
                    IsCurrent=$is_current
                    Version=$_.Name
                }
            }
    } | Where-Object {
        !$App -or ($_.App -eq $App)
    } | Where-Object {
        !$Version -or ($_.Version -eq $Version)
    }
}

Export-ModuleMember -Function Get-USMApp

<#
.SYNOPSIS
Removes the given application version.

.DESCRIPTION
This deletes a given version, checking before that the given version is not
assigned as the current version for its application.

This can also delete all the versions of an application if the -RemoveAll is
specified.

.PARAMETER App
The application to remove the version of (or to remove if -RemoveAll is provdied)

.PARAMETER Version
The version to remove. This must be provided if -RemoveAll is not, and must
not be provided if -RemoveAll is.

.PARAMETER RemoveAll
Whether to remove all versions of the application.
#>
function Remove-USMApp([string] $App, [string] $Version = $null, [switch] $RemoveAll = $false) {
    if ($RemoveAll -and $Version) {
        throw "A version should not be provided when removing all versions"
    }

    if (!$RemoveAll -and !$Version) {
        throw "Either a version or RemoveAll must be provided"
    }

    $target_app = get_app_path $App
    if (!(Test-Path $target_app)) {
        throw "App $App does not exist"
    }

    if ($RemoveAll) {
        Remove-Item -Recurse -Force $target_app
    } else {
        if ((get_current_version $App) -eq $Version) {
            throw "The current version for $App is set to $Version, cannot delete that version"
        }

        Remove-Item -Recurse -Force (Join-Path $target_app $Version)
    }
}

Export-ModuleMember -Function Remove-USMApp
