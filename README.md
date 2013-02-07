perl-plugin
===========

build, deploy and test perl applications with jenkins CI server 


exported builders
===
- perl_builder

This is smart builder for perl based applications. Builder algorithm:
- goes through $WORKSPACE/svn/* directories - `'applications'`
- for every application founds last tag if possible
- for every found tag makes installation:
    - setup local::lib environment 
    - adds $WORKSPACE/cpanlib directory to local::lib environment
    - installs current working directory with cpanminus client
- if application directory is in `$WORKSPACE/svn/app/*`
    - creates applications distributive 
    - adds $WORKSPACE/cpanlib into distributive tarball
    - copies distributive to artifacts directory ($WORKSPACE/build)

- example layout:
    $WORKSPACE/svn/module/version-0.0.1
    $WORKSPACE/svn/module/version-0.0.1
    $WORKSPACE/svn/app/version-0.1.0
    $WORKSPACE/svn/app/version-0.2.0

exported publshers
===
- perl_publisher
