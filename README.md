# perl-plugin

build and create distributive of perl application

# prerequisites

following packages should be installed:

- [App::cpanminus](http://search.cpan.org/perldoc?App%3A%3Acpanminus)
- [local::lib](http://search.cpan.org/perldoc?local%3A%3Alib)


# exported builders

`Build perl project`

- Builds and optionally create distributive for perl application
- Build process consists of these steps:
    - cwd to `source directory` directory
    - if `lookup last tag` is set find 'tagged' directory with maximum version number and cwd to it
    - setup local::lib to `workspace/cpanlib` directory
    - runs "cpanmini -i ." to install everithing into `workspace/cpanlib` directory 
- Make distrubitive process consists of these steps:
    - cwd to `source directory` directory
    - copy workspace/cpanlib into current working directory
    - create cpan distributive ( Build.PL and Makefile.PL files are supported)
    - copy cpan distributive to `distributive directory`
    - doing cleanup (supplimental files are deleted)
 

## parameters:

![layout](https://raw.github.com/melezhik/perl-plugin/master/images/layout.png "layout")

- `enabled`: enable/disable build step
- `source directrory`: directory where build runs ( should have cpan compatible structure - have Makefile.PL or Build.PL file )
- `lookup last tag`: whether to look up 'tagged' directory with maximum version number in `source directory`
- `create distributive`: whether to create cpan distributive ( will be stored in `distributive directory` )
- `distributive directory` 	path to directory where to store distributive


# advanced options:

- `color output`: enable/disable color output
- `verbose output`: enable/disable verbose output
- `enable catalyst debug mode`: run catalyst tests in debug mode

## patches:

![patches text-area](https://raw.github.com/melezhik/perl-plugin/master/images/patches.png "patches text-area")

Patches are just stanzas in cpanminus client format, they are passed to cpanminus client as arguments. 
The reason you may want to use patches is to forcefully install some problematic cpan modules or install downgraded versions. 
Patches are the right way to do this. Once patches are applied you may comment them or prepend with `--skip-satisfied` flag. 
Check out http://search.cpan.org/perldoc?cpanm for details.

Patches examples:

    # any comments start with '#'
    -f Math::Currency # forcefully installation
    --skip-satisfied CGI DBI~1.2
    http://search.cpan.org/CPAN/authors/id/D/DO/DOY/Moose-2.0604.tar.gz

# Environment setup

You can set environment variables via "Jenkins/Configuration/Global properties/Environment variables" interface to adjust plugin behaviour.

## cpan_mirror
Setup one if you have custom cpan mirror, for example private mini cpan server.
    
    http://my.private.cpan.local

## http_proxy
Standard way to do things when you behind http proxy server.

    http://my.proxy.server

## LC_ALL
Setup your standard encoding.

    ru_RU.UTF-8

