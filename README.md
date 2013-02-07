perl-plugin
===========

build, deploy and test perl applications with jenkins CI server 

prerequisites

exported builders
===
- perl_builder

This is smart builder for perl based applications. Builder algorithm:
- goes through $WORKSPACE/svn/* directories - 'applications'
- for every application founds last tag if possible ($WORKSPACE/svn/\*/\*/)
- for every found tag makes installation:
    - set-up local::lib environment 
    - adds $WORKSPACE/cpanlib directory to local::lib environment
    - installs current working directory with [cpanminus](http://search.cpan.org/perldoc?cpanm) client
- if application directory is in `$WORKSPACE/svn/app/*`
    - creates applications distributive with [Module::Build](http://search.cpan.org/perldoc?Module%3A%3ABuild) installer 
    - adds $WORKSPACE/cpanlib into distributive tarball
    - copies distributive to artefacts directory ($WORKSPACE/build)


example layout:

    $WORKSPACE/svn/module/version-0.0.1
    $WORKSPACE/svn/module/version-0.0.2
    $WORKSPACE/svn/app/version-0.1.0
    $WORKSPACE/svn/app/version-0.2.0

- tags found : $WORKSPACE/svn/module/version-0.0.1, $WORKSPACE/svn/app/version-0.2.0, 
- distributive made from: $WORKSPACE/svn/app/version-0.2.0

exported publishers
===
- perl_publisher
