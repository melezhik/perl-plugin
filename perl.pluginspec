Jenkins::Plugin::Specification.new do |plugin|
  plugin.name = "perl"
  plugin.display_name = "Perl Plugin"
  plugin.version = '0.0.2'
  plugin.description = 'build, deploy and test perl applications with jenkins CI server'

  # You should create a wiki-page for your plugin when you publish it, see
  # https://wiki.jenkins-ci.org/display/JENKINS/Hosting+Plugins#HostingPlugins-AddingaWikipage
  # This line makes sure it's listed in your POM.
  # plugin.url = 'https://github.com/melezhik/perl-plugin'
  plugin.url = 'https://wiki.jenkins-ci.org/display/JENKINS/Perl+Plugin'

  # The first argument is your user name for jenkins-ci.org.
  plugin.developed_by "melezhik", "Alexey Melezhik <melezhik@gmail.com>"

  # This specifies where your code is hosted.
  # Alternatives include:
  #  :github => 'myuser/foo-plugin' (without myuser it defaults to jenkinsci)
  #  :github => 'melezhik/perl-plugin'
  #  :git => 'git://repo.or.cz/foo-plugin.git'
  #  :svn => 'https://svn.jenkins-ci.org/trunk/hudson/plugins/foo-plugin'
  plugin.uses_repository :github => "melezhik/perl-plugin"

  # This is a required dependency for every ruby plugin.
  plugin.depends_on 'ruby-runtime', '0.10'

  # This is a sample dependency for a Jenkins plugin, 'git'.
  #plugin.depends_on 'git', '1.1.11'
end

