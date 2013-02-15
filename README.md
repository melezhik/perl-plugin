perl-plugin
===========

build perl applications under Jenkins CI server 

prerequisites
===

following packages should be installed:

- [App::cpanminus](http://search.cpan.org/perldoc?App%3A%3Acpanminus)

exported builders
===

## perl_builder

This is the smart builder for perl based applications. Builder algorithm is:

- for every subdirectory in `$WORKSPACE/svn/*/` list founds "last tag" directory (with the biggest version postfix) -  `$WORKSPACE/svn/*/<last_tag>`
- for every `<last_tag>` directory:
    - cwd `<last_tag>`
    - set-up local::lib environment 
    - adds $WORKSPACE/cpanlib directory to local::lib environment
    - runs installation from current working directory with [cpanminus](http://search.cpan.org/perldoc?cpanm) client
- if `<last_tag>` directory is held in `$WORKSPACE/svn/app/` directory:
    - creates `distributive` from `<last_tag>` directory with [Module::Build](http://search.cpan.org/perldoc?Module%3A%3ABuild) installer 
    - copies $WORKSPACE/cpanlib to distributive tarball (incremental build!)
    - copies distributive tarball to artifacts directory ($WORKSPACE/build)
    - copies notes.markdown file and patches text-area content to ($WORKSPACE/build)


### example layout:

    $WORKSPACE/svn/module/version-0.0.1
    $WORKSPACE/svn/module/version-0.0.2
    $WORKSPACE/svn/app/version-0.1.0
    $WORKSPACE/svn/app/version-0.2.0

- `<last_tag>` directories found: $WORKSPACE/svn/module/version-0.0.2, $WORKSPACE/svn/app/version-0.2.0, 
- `distributive` made from directory: $WORKSPACE/svn/app/version-0.2.0

### interface:

![layout](https://raw.github.com/melezhik/perl-plugin/master/images/layout.png "layout")

- `run build process`: enable/disable builder
- `enable catalyst debug mode`: run catalyst tests in debug mode
- `do not lookup last tag`: do not find last tags in `$WORKSPACE/svn/*/` directories, runs installation from `$WORKSPACE/svn/*/` directories
- `verbosity type`: level of verbosity of output in Jenkins console

### advanced options:

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

You can set environment variables via "Jenkins/Configuration/Global properties/Environment variables" interface to adjust plugin behavior.

## cpan_mirror
Setup one if you have custom cpan mirror, for example private mini cpan server.
    
    http://my.private.cpan.local

## http_proxy
Standard way to do things when you behind http proxy server.

    http://my.proxy.server

## LC_ALL
Setup your standard encoding.

    ru_RU.UTF-8






