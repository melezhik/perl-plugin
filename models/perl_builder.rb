require "versionomy"
require 'term/ansicolor'
    
class PerlBuilder < Jenkins::Tasks::Builder
    include Term::ANSIColor

    attr_accessor :attrs, :enabled, :verbosity_type, :catalyst_debug, :dist_dir
    attr_accessor :lookup_last_tag, :patches, :make_dist, :source_dir, :color_output

    display_name "Build perl project" 

    # Invoked with the form parameters when this extension point
    # is created from a configuration screen.
    def initialize(attrs = {})
        @attrs = attrs
        @enabled = attrs["enabled"]
        @verbosity_type = attrs["verbosity_type"]
        @catalyst_debug = attrs["catalyst_debug"]
        @lookup_last_tag = attrs["lookup_last_tag"]
        @patches = attrs["patches"] || ""
        @make_dist = attrs["make_dist"]
        @source_dir = attrs["source_dir"]
        @color_output = attrs["color_output"]
        @dist_dir = attrs["dist_dir"]
    end
    def default_cpan_mirror
        "http://cpan.dk"
    end
    ##
    # Runs before the build begins
    #
    # @param [Jenkins::Model::Build] build the build which will begin
    # @param [Jenkins::Model::Listener] listener the listener for this build.
    def prebuild(build, listener)
      # do any setup that needs to be done before this build runs.
    end

    ##
    # Runs the step over the given build and reports the progress to the listener.
    #
    # @param [Jenkins::Model::Build] build on which to run this step
    # @param [Jenkins::Launcher] launcher the launcher that can run code on the node running this build
    # @param [Jenkins::Model::Listener] listener the listener for this build.
    def perform(build, launcher, listener)
        raise ArgumentError, bold(red("dist dir not be empy")) if @dist_dir.nil? || @dist_dir.empty?

      # actually perform the build step
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

        listener.info("verbosity_type: #{@verbosity_type}")
        listener.info("enabled: #{@enabled}")
        cpan_mirror = env['cpan_mirror'] || default_cpan_mirror
        cpan_source_chunk = (cpan_mirror.nil? || cpan_mirror.empty?) ? "" :  "--mirror #{cpan_mirror}  --mirror-only"

        # clean up old build directory
        listener.info "clean up #{workspace}/#{@dist_dir} directory"
        cmd = []
        cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
        cmd << "rm -rf #{workspace}/#{@dist_dir}"
        cmd << "mkdir #{workspace}/#{@dist_dir}"
        cmd << "touch #{workspace}/#{@dist_dir}/.empty"
        build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

        # start build
        if @enabled == true 
            # setup verbosity  
            if @verbosity_type == 'high'
                File.open("#{workspace}/modulebuildrc", 'w') {|f| f.write("test verbose=1") }
            else  
                File.open("#{workspace}/modulebuildrc", 'w') {|f| f.write("test verbose=0") }
            end      
                
            # apply patches
            @patches.split("\n").map {|l| l.chomp }.reject {|l| l.nil? || l.empty? || l =~ /^\s+#/ || l =~ /^#/ }.map{ |l| l.sub(/#.*/){""} }.each do |l|
                listener.info (@color_output == true) ? "#{black(red(bold("apply patch:")))} #{bold(black(blue("#{l}")))}" : "apply patch: #{l}"
                cmd = []
                cpan_mini_verbose = @verbosity_type == 'none' ? '' : '-v'
                cmd << "export CATALYST_DEBUG=1" if @catalyst_debug == true 
                cmd << "export MODULEBUILDRC=#{workspace}/modulebuildrc"
                cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
                cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
                cmd << "eval $(perl -Mlocal::lib=#{workspace}/cpanlib)"
                cmd << "cpanm --curl #{cpan_mini_verbose} #{cpan_source_chunk} #{l}"
                build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0
            end  

            # build from source
            if @lookup_last_tag == false             
                s_dir = source_dir
            else
                begin
                    s_dir = Dir.glob("#{source_dir}/*").select {|f2| File.directory? f2}.sort { |x,y| 
                        Versionomy.parse(File.basename(x).sub(/.*-/){""}) <=> Versionomy.parse(File.basename(y).sub(/.*-/){""}) 
                    }.last
                rescue Versionomy::Errors::ParseError => ex
                    raise ex, bold(red("Some folders name does not contain version number."))
                rescue Exception => ex
                    raise ex
                end
            end

            listener.info (@color_output == true) ? "#{black(red(bold("building from source:")))} #{bold(black(blue("#{s_dir}")))}" : "building from source: #{s_dir}"
            cmd = []
            cpan_mini_verbose = @verbosity_type == 'none' ? '' : '-v'
            
            cmd << "export CATALYST_DEBUG=1" if @catalyst_debug == true 
            cmd << "export MODULEBUILDRC=#{workspace}/modulebuildrc"
            cmd << "export LC_ALL=ru_RU.UTF-8 && cd #{s_dir}"
            cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
            cmd << "eval $(perl -Mlocal::lib=#{workspace}/cpanlib)"
            cmd << "cpanm --curl #{cpan_mini_verbose} #{cpan_source_chunk} ."
            build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

            # make dist
            if @make_dist == true

                if @lookup_last_tag == false 
                    app_s_dir  = source_dir            
                else
                    begin
                        app_s_dir = Dir.glob("#{source_dir}/*").select {|f2| File.directory? f2}.sort { |x,y|
                            Versionomy.parse(File.basename(x).sub(/.*-/){""}) <=> Versionomy.parse(File.basename(y).sub(/.*-/){""}) 
                        }.last
                    rescue Versionomy::Errors::ParseError => ex
                        raise ex, bold(red("Some folders name does not contain version number."))
                    rescue Exception => ex
                        raise ex
                    end
                end

                listener.info (@color_output == true) ? "#{black(red(bold("creating distributive from:")))}  #{bold(black(blue("#{app_s_dir}")))}" : "creating distributive from: #{app_s_dir}"
                cmd = []
                module_build_verbosity = ''
                if @verbosity_type == 'none' 
                    module_build_verbosity = '--quiet'
                elsif @verbosity_type == 'medium' 
                    module_build_verbosity = ''
                elsif @verbosity_type == 'High'
                    module_build_verbosity = '--verbose'
                end

                cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
                cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
                cmd << "eval $(perl -Mlocal::lib=#{workspace}/cpanlib)"
                cmd << "cd #{app_s_dir}"
                cmd << "rm -rf ./cpanlib"
                cmd << "cp -r #{workspace}/cpanlib/ ."
                cmd << "rm -rf *.gz"
                cmd << "rm -rf MANIFEST"
                cmd << "perl Build.PL #{module_build_verbosity} && ./Build manifest #{module_build_verbosity}"
                cmd << "./Build dist #{module_build_verbosity}"
                cmd << "rm -rf #{workspace}/#{@dist_dir}/"
                cmd << "mkdir #{workspace}/#{@dist_dir}"
                cmd << "mv *.gz #{workspace}/#{@dist_dir}/"
                cmd << "rm -rf *.gz"
                cmd << "rm -rf ./cpanlib"
                build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

                distroname = File.basename(Dir.glob("#{workspace}/#{@dist_dir}/*.tar.gz").last)

                # basename of distributive will be added to artifatcs
                distro_url = "#{env['JENKINS_URL']}/job/#{job}/#{build_number}/artifact/#{@dist_dir}/#{distroname}"
                File.open("#{workspace}/#{@dist_dir}/distro.url", 'w') { |f| f.write(distro_url) }
                listener.info (@color_output == true) ? "#{black(red(bold("distro.url:")))} #{bold(black(blue("#{distro_url}")))}" : "distro.url: #{distro_url}"
            end
        end # if @enabled == true

    end

end
