perl-plugin
===========

build, deploy and test perl applications with jenkins CI server 

prerequisites
===
- cpanminus
- rvm
- ruby 1.8.7


exported builders
===

## perl_builder

This is smart builder for perl based applications. Builder algorithm:

- for every subdirectory in `$WORKSPACE/svn/*/` list founds "last tag" directory (with the biggest version postfix) -  `$WORKSPACE/svn/*/<last_tag>`
- for every `<last_tag>` directory:
    - cwd `<last_tag>`
    - set-up local::lib environment 
    - adds $WORKSPACE/cpanlib directory to local::lib environment
    - runs installation from current working directory with [cpanminus](http://search.cpan.org/perldoc?cpanm) client
- if `<last_tag>` directory is held in `$WORKSPACE/svn/app/` directory:
    - creates `distributive` from `<last_tag>` directory with [Module::Build](http://search.cpan.org/perldoc?Module%3A%3ABuild) installer 
    - copies $WORKSPACE/cpanlib to distributive tarball (incremental build!)
    - copies distributive tarball to artefacts directory ($WORKSPACE/build)


### example layout:

    $WORKSPACE/svn/module/version-0.0.1
    $WORKSPACE/svn/module/version-0.0.2
    $WORKSPACE/svn/app/version-0.1.0
    $WORKSPACE/svn/app/version-0.2.0

- `<last_tag>` directories found: $WORKSPACE/svn/module/version-0.0.2, $WORKSPACE/svn/app/version-0.2.0, 
- `distributive` made from directory: $WORKSPACE/svn/app/version-0.2.0

### interface:

![perl_builder interface](https://raw.github.com/melezhik/perl-plugin/master/images/perl-builder-interface.png "perl_builder interface")

- `run build process`: enable/disable builder
- `enable catalyst debug mode`: run catalyst tests in debug mode
- `do not lookup last tag`: do not find last tags in `$WORKSPACE/svn/*/` directories, runs installation from `$WORKSPACE/svn/*/` directories
- `chef json template`: [ERB](http://www.stuartellis.eu/articles/erb/) template for generated [chef json file](http://wiki.opscode.com/display/chef/Setting+the+run_list+in+JSON+during+run+time) (see further for explanation)
- `verbosity type`: level of verbosity of output in jenkins console

### chef json template
If you define one, perl_builder will generate chef json file, based on the template. Check out chef wiki to get know about chef json files. 
The only important perl_builder do about json file is adding link to artefact URL to it.

### advanced options:

![patches textarea](https://raw.github.com/melezhik/perl-plugin/master/images/perl_builder_patches.png "patches textarea")

Patches are just stanzas in cpanminus client format, they are passed to cpanminus client as arguments. The reason you may want to use patches is to forcefully install some problematic cpan modules 
or install downgraded versions. Patches are the right way to this. Once patches are applied you may comment them or prepend with `--skip-satisfied` flag.


exported publishers
===

## perl_publisher

This publsher should be run after logically perl_buider, it does two things:

- run chef-client on remote server (see deploy on remote server section)
- run cucumber tests (see run cucumber tests section)

### deploy on remote server
chef-client will be run on remote server with chef json file generated by perl_builder for you, SSH Public-Key Authentication is used.

![perl_publisher_chef](https://raw.github.com/melezhik/perl-plugin/master/images/perl_publisher_chef.png "perl_publisher_chef interface")

### run cucumber tests
- cucumber tests may be optionally run, it's simple wrapper around `bundle exec cucumber` command. 
- for this to work rvm should be installed in `Single-User Install Location` way for user jenkins 

![perl_publisher_cucumber](https://raw.github.com/melezhik/perl-plugin/master/images/perl_publisher_cucumber.png "perl_publisher_cucumber interface")





