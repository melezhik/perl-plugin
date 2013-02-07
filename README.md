perl-plugin
===========

build, deploy and test perl applications with jenkins CI server 

prerequisites

exported builders
===

## perl_builder

This is smart builder for perl based applications. Builder algorithm:

- goes through `$WORKSPACE/svn/*` directories - 'applications'
- for every application founds last tag if possible ($WORKSPACE/svn/\*/\*/)
- for every found tag makes installation:
    - set-up local::lib environment 
    - adds $WORKSPACE/cpanlib directory to local::lib environment
    - runs installation from current working directory with [cpanminus](http://search.cpan.org/perldoc?cpanm) client
- if application directory is in `$WORKSPACE/svn/app/*`
    - creates applications distributive from current working directory with [Module::Build](http://search.cpan.org/perldoc?Module%3A%3ABuild) installer 
    - copies $WORKSPACE/cpanlib to distributive tarball (incremental build!)
    - copies distributive tarball to artefacts directory ($WORKSPACE/build)


example layout:

    $WORKSPACE/svn/module/version-0.0.1
    $WORKSPACE/svn/module/version-0.0.2
    $WORKSPACE/svn/app/version-0.1.0
    $WORKSPACE/svn/app/version-0.2.0

- tags found : $WORKSPACE/svn/module/version-0.0.1, $WORKSPACE/svn/app/version-0.2.0, 
- distributive made from: $WORKSPACE/svn/app/version-0.2.0

interface:

![perl_builder interface](https://raw.github.com/melezhik/perl-plugin/master/images/perl-builder-interface.png "perl_builder interface")

- `run build process` : enable/disable builder
- `enable catalyst debug mode` : run catalyst tests in debug mode
- `do not lookup last tag`: do not try find tags in `$WORKSPACE/svn/*` directory, runs installation from `$WORKSPACE/svn/*` itself
- `chef json template`: [ERB](http://www.stuartellis.eu/articles/erb/) template for gerenerated (chef json file)[http://wiki.opscode.com/display/chef/Setting+the+run_list+in+JSON+during+run+time] (see further for explanation)
- `verbosity type`: level of verbosity for output in jenkins console


exported publishers
===

## perl_publisher

