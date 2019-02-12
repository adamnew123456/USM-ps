# What is this?

USM is a PATH management tool that provides a middle ground between two typical
techniques for installing software as a normal user:

- Add a single directory to your PATH, and shove all of your programs and
  scripts into that directory. This is simple to add software to and to use, but
  difficult to manage since there's no way to know what files belong to what
  software.

- Create a new directory for each program or collection of scripts and add it
  to your PATH. This is cleaner to manage since each you know what every file
  belongs to, but hard to add to and use since you have to manage lots of
  directories and a lot of PATH entires.

USM takes the second approach, but automates updating your PATH and
adding/removing all the necessary directories. In addition, it also lets you
have multiple versions of each piece of software and switch between them
dynamically.

The original version of [USM](https://github.com/adamnew123456/USM) is written
in POSIX shell script, which works in environments like Cygwin and Git Bash,
but not on a native Windows shell.

# Requirements

Just Powershell. Most testing has been on Linux, but it should work on all
platforms that Powershell core supports.

# Usage
## Getting Started

1. Create a USM directory inside one of the directories in your
   $env:PSModulePath and copy USM.ps1 into it.

2. Run `Import-Module USM` and then `Install-USM`. This will install the
   .usm.ps1 script and USM Apps directory (by default into your HOME or
   HOMEPATH, see the `Install-USM` help if you want to override this behavior).

3. Follow the instructions printed after running `Install-USM`.

## Adding Software

To add new software, you can use `Add-USMApp`:

    PS> Add-USMApp -App some-scripts -Version 1.0
    PS> cd "$env:USM_PATH/some-scripts/1.0"
    PS> mkdir bin
    PS> echo 'Write-Output "Hello world from Powershell!"' > hello.ps1

Make sure to dot-source your .usm.ps1 script after adding or removing software
to ensure that your PATH is updated.

    PS> . ~/.usm.ps1
    PS> cd ~
    PS> hello.ps1
    Hello world from Powershell!

## Changing the Current Version

USM supports multiple versions of each software, only one of which can be the
current version. Whatever version is the current one is what's included on your
PATH. You can think of these versions like Git branches, where each is separate
from the others and only one can be checked out at once.

Adding a new piece of software creates a new version and automatically marks it
as the default, so that you can start using it immediately, but you can also
add other versions:

    PS> Add-USMApp -App some-scripts -Version 2.0
    PS> cd "$env:USM_PATH/some-scripts/2.0"
    PS> mkdir bin
    PS> echo 'Write-Output "Advanced hello world from Powershell!"' > hello.ps1

You can switch between them dynamically (without having to reload your .usm.ps1)
using `Switch-USMAppVersion`:

    PS> Switch-USMAppVersion -App some-scripts -Version 2.0
    PS> hello.ps1
    Advanced hello world from Powershell!
    PS> Switch-USMAppVersion -App some-scripts -Version 1.0
    PS> hello.ps1
    Hello world from Powershell!

## Listing Software and Versions

You can use `Get-USMApp` to view the software you currently have installed:

    PS> Get-USMApp
    App          IsCurrent Version
    ---          --------- -------
    some-scripts True      1.0
    some-scripts False     2.0

## Removing Software

You can remove individual versions using `Remove-USMApp`. Make sure to set the
current version if you need to delete the current version:

    PS> Remove-USMApp -App some-scripts -Version 2.0

If you need to remove the whole application, you can also use the `-RemoveAll`
flag instead of providing a version:

    PS> Remove-USMApp -App some-scripts -RemoveAll
