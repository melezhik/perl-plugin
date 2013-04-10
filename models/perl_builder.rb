require "versionomy"
require 'simple/console'
    
class PerlBuilder < Jenkins::Tasks::Builder

    attr_accessor :attrs, :enabled, :verbose_output, :catalyst_debug, :dist_dir, :install_base
    attr_accessor :lookup_last_tag, :patches, :make_dist, :source_dir, :color_output, :env_vars

    display_name "Build perl project" 
  
    # Invoked with the form parameters when this extension point
    # is created from a configuration screen.
    def initialize(attrs = {})
        @attrs = attrs
        @enabled = attrs["enabled"]
        @verbose_output = attrs["verbose_output"]
        @catalyst_debug = attrs["catalyst_debug"]
        @lookup_last_tag = attrs["lookup_last_tag"]
        @patches = attrs["patches"] || ""
        @make_dist = attrs["make_dist"]
        @source_dir = attrs["source_dir"]
        @color_output = attrs["color_output"]
        @dist_dir = attrs["dist_dir"]
        @env_vars = attrs["env_vars"]
        @install_base = attrs["install_base"]
    end
    ##
    # Runs before the build begins
    #
    # @param [Jenkins::Model::Build] build the build which will begin
    # @param [Jenkins::Model::Listener] listener the listener for this build.
    def prebuild(build, listener)
      # do any setup that needs to be done before this build runs.
    end

    def search_last_tag(directory)
            sc = Simple::Console.new(:color_output => @color_output)
            source_directory = Dir.glob("#{directory}/*").select {|f2| File.directory? f2}.sort { |x,y| 
                Versionomy.parse(File.basename(x).sub(/.*-/){""}) <=> Versionomy.parse(File.basename(y).sub(/.*-/){""}) 
            }.last
        rescue Versionomy::Errors::ParseError => ex
            raise ex, sc.error("Upps. It seems the directory does not hold tagged directories with version numbers. Versionomy::Errors::ParseError: #{ex.message}")
        rescue Exception => ex
            raise ex
    end

    def evaluate_env_vars(string)

        retval = nil

        if @environment_variables_string.nil?
            unless string.nil? || string.empty?
                string.gsub!(/(\s+=\s+|=\s+|\s+=)/, '=')
                @environment_variables_string = string.split(' ').map{|x| "export #{x}"}.join(' && ')
                retval = @environment_variables_string
            else
                @environment_variables_string = ''
                retval = @environment_variables_string
            end
        else
            retval = @environment_variables_string
        end

        retval

    end

    ##
    # Runs the step over the given build and reports the progress to the listener.
    #
    # @param [Jenkins::Model::Build] build on which to run this step
    # @param [Jenkins::Launcher] launcher the launcher that can run code on the node running this build
    # @param [Jenkins::Model::Listener] listener the listener for this build.
    def perform(build, launcher, listener)
      # actually perform the build step
        sc = Simple::Console.new(:color_output => @color_output)
        env = build.native.getEnvironment()
        workspace = build.send(:native).workspace.to_s
        build_number = build.send(:native).get_number
        job = build.send(:native).get_project.name
        source_dir = nil
        if @source_dir.nil? || @source_dir.empty?
            source_dir = workspace
        else
            source_dir = "#{workspace}/#@source_dir"
        end

        if @install_base.empty?
            @install_base = 'cpanlib'
        end

        app_install_base = File.expand_path(@install_base.gsub(/\s+/, ''),workspace)

        raise sc.error("Source directory does not exist.") if File.directory?(source_dir) == false
        raise sc.error("Source directory couldn't be workspace") if File.expand_path(workspace) == app_install_base

        listener.info sc.info("#{@enabled}", :title => 'enabled')

        # start build
        if @enabled == true 
            # setup cpan mirror  
            cpan_mirror = env['cpan_mirror']
            cpan_source_chunk = (cpan_mirror.nil? || cpan_mirror.empty?) ? "" :  "--mirror #{cpan_mirror}  --mirror-only"
            # setup verbosity  
            if @verbose_output == true
                File.open("#{workspace}/modulebuildrc", 'w') {|f| f.write("test verbose=1") }
            else  
                File.open("#{workspace}/modulebuildrc", 'w') {|f| f.write("test verbose=0") }
            end      
            
            # apply patches
            @patches.split("\n").map {|l| l.chomp }.reject {|l| l.nil? || l.empty? || l =~ /^\s+#/ || l =~ /^#/ }.map{ |l| l.sub(/#.*/){""} }.each do |l|
                listener.info sc.info(l, :title => 'apply patch')
                cmd = []
                cpan_mini_verbose = @verbose_output == false ? '' : '-v'
                cmd << evaluate_env_vars(@env_vars)
                cmd << "export CATALYST_DEBUG=1" if @catalyst_debug == true 
                cmd << "export MODULEBUILDRC=#{workspace}/modulebuildrc"
                cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
                cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
                cmd << "eval $(perl -Mlocal::lib=#{app_install_base})"

                cmd << "cpanm --curl #{cpan_mini_verbose} #{cpan_source_chunk} #{l}"
                build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0
            end  

            # build from source
            if @lookup_last_tag == false             
                s_dir = source_dir
            else
                s_dir = search_last_tag(source_dir)
            end

            listener.info sc.info( s_dir, :title => 'building from source')
            cmd = []
            cpan_mini_verbose = @verbose_output == false ? '--quiet' : '-v'
            
            cmd << evaluate_env_vars(@env_vars)
            cmd << "export CATALYST_DEBUG=1" if @catalyst_debug == true 
            cmd << "export MODULEBUILDRC=#{workspace}/modulebuildrc"
            cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
            cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
            cmd << "cd #{s_dir}"
            cmd << "eval $(perl -Mlocal::lib=#{app_install_base})"
            cmd << "cpanm --curl #{cpan_mini_verbose} #{cpan_source_chunk} ."
            build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

            # make dist
            if @make_dist == true

                raise ArgumentError, sc.error("dist dir is required parameter") if @dist_dir.nil? || @dist_dir.empty?

                # clean up dist directory
                listener.info "clean up #{workspace}/#{@dist_dir} directory"
                cmd = []
                cmd << evaluate_env_vars(@env_vars)
                cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
                cmd << "rm -rf #{workspace}/#{@dist_dir}"
                cmd << "mkdir -p #{workspace}/#{@dist_dir}"
                cmd << "touch #{workspace}/#{@dist_dir}/.empty"
                build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0


                if @lookup_last_tag == false 
                    app_s_dir  = source_dir            
                else
                    app_s_dir = search_last_tag(source_dir)
                end

                listener.info sc.info(app_s_dir, :title => 'creating distributive from')
                cmd = []
                module_build_verbosity = ''
                if @verbose_output == false 
                    module_build_verbosity = '--quiet'
                elsif @verbose_output == true
                    module_build_verbosity = '--verbose'
                end

                # don't echo commands. '-s' - silent.
                if @verbose_output == false 
                    make_maker_verbosity = '-s'
                end

                cmd << evaluate_env_vars(@env_vars)
                cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
                cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
                cmd << "eval $(perl -Mlocal::lib=#{workspace}/#@install_base)"
                cmd << "cd #{app_s_dir}"
                cmd << "rm -rf #{app_install_base}"
                cmd << "cp -r #{app_install_base}/ ."
                cmd << "rm -rf *.gz"
                cmd << "rm -rf MANIFEST"

                if  File.exist?("#{app_s_dir}/Build.PL")
                    cmd << "perl Build.PL #{module_build_verbosity} && ./Build manifest #{module_build_verbosity}"
                    cmd << "./Build dist #{module_build_verbosity}"
                elsif File.exist?("#{app_s_dir}/Makefile.PL")
                    cmd << "rm -f MANIFEST"
                    cmd << "perl Makefile.PL && make manifest #{make_maker_verbosity} && make dist #{make_maker_verbosity}"
                end

                cmd << "rm -rf #{workspace}/#{@dist_dir}/"
                cmd << "mkdir -p #{workspace}/#{@dist_dir}"
                cmd << "mv *.gz #{workspace}/#{@dist_dir}/"
                cmd << "rm -rf *.gz"
                cmd << "rm -rf #{app_install_base}"
                build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

                distroname = File.basename(Dir.glob("#{workspace}/#{@dist_dir}/*.tar.gz").last)

                # basename of distributive will be added to artifatcs
                distro_url = "#{env['JENKINS_URL']}/job/#{job}/#{build_number}/artifact/#{@dist_dir}/#{distroname}"
                File.open("#{workspace}/#{@dist_dir}/distro.url", 'w') { |f| f.write(distro_url) }
                listener.info sc.info(distro_url, :title => 'distro.url')
            end

        end # if @enabled == true

    end

end

