# perl-plugin

build perl applications under Jenkins CI server 

# prerequisites

following packages should be installed:

- [App::cpanminus](http://search.cpan.org/perldoc?App%3A%3Acpanminus)

# exported builders

`Build perl project`

- Builds and optionally create distributive for perl application

## parameters:

![layout](https://raw.github.com/melezhik/perl-plugin/master/images/layout.png "layout")

- `run build process`: enable/disable build step
- `source directrory`: directory where build runs ( should have cpan compatible structure - have Makefile.PL or Build.PL file )
- `lookup last tag`: whether to look up tag with maximum version in `source directory`
- `create distributive`: where to create cpan distributive ( will be stored in `distributive` directory)
- `verbosity type`: level of verbosity
- `enable catalyst debug mode`: run catalyst tests in debug mode

# advanced options:

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





