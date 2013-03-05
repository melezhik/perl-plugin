require "versionomy"
require 'term/ansicolor'

###
    
class PerlBuilder < Jenkins::Tasks::Builder
    include Term::ANSIColor

    attr_accessor :attrs, :enabled, :verbosity_type, :catalyst_debug, :look_last_tag, :patches, :make_dist, :source_dir, :color_output

    display_name "Build perl project" 

    # Invoked with the form parameters when this extension point
    # is created from a configuration screen.
    def initialize(attrs = {})
        @attrs = attrs
        @enabled = attrs["enabled"]
        @verbosity_type = attrs["verbosity_type"]
        @catalyst_debug = attrs["catalyst_debug"]
        @look_last_tag = attrs["look_last_tag"]
        @patches = attrs["patches"] || ""
        @make_dist = attrs["make_dist"]
        @source_dir = attrs["source_dir"]
        @color_output = attrs["color_output"]
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

        listener.info("plugin input parameters: #{@attrs}")
        listener.info("verbosity_type: #{@verbosity_type}")
        listener.info("enabled: #{@enabled}")
        cpan_mirror = env['cpan_mirror'] || default_cpan_mirror
        cpan_source_chunk = (cpan_mirror.nil? || cpan_mirror.empty?) ? "" :  "--mirror #{cpan_mirror}  --mirror-only"

        # clean up old build directory
        listener.info "clean up #{workspace}/build directory"
        cmd = []
        cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
        cmd << "rm -rf #{workspace}/build"
        cmd << "mkdir #{workspace}/build"
        cmd << "touch #{workspace}/build/.empty"
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
                listener.info green("apply patch: #{l}")
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

            if @look_last_tag == false             
                last_tag = source_dir
            else
                last_tag = Dir.glob("#{source_dir}/*").select {|f2| File.directory? f2}.sort { |x,y| 
                    Versionomy.parse(File.basename(x).sub(/.*-/){""}) <=> Versionomy.parse(File.basename(y).sub(/.*-/){""}) 
                }.last
            end

            listener.info @color_output == true ? green("building last tag: #{last_tag}") : "building last tag: #{last_tag}"
            cmd = []
            cpan_mini_verbose = @verbosity_type == 'none' ? '' : '-v'
            
            cmd << "export CATALYST_DEBUG=1" if @catalyst_debug == true 
            cmd << "export MODULEBUILDRC=#{workspace}/modulebuildrc"
            cmd << "export LC_ALL=ru_RU.UTF-8 && cd #{last_tag}"
            cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
            cmd << "eval $(perl -Mlocal::lib=#{workspace}/cpanlib)"
            cmd << "cpanm --curl #{cpan_mini_verbose} #{cpan_source_chunk} ."
            build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

            if @make_dist == true

                if @look_last_tag == false 
                    app_last_tag  = source_dir            
                else
                    app_last_tag = Dir.glob("#{source_dir}/*").select {|f2| File.directory? f2}.sort { |x,y|
                        Versionomy.parse(File.basename(x).sub(/.*-/){""}) <=> Versionomy.parse(File.basename(y).sub(/.*-/){""}) 
                    }.last
                end

                listener.info @color_output == true ? green("creating distributive from last tag: #{app_last_tag}") : "creating distributive from last tag: #{app_last_tag}"
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
                cmd << "cd #{app_last_tag}"
                cmd << "rm -rf ./cpanlib"
                cmd << "cp -r #{workspace}/cpanlib/ ."
                cmd << "rm -rf *.gz"
                cmd << "rm -rf MANIFEST"
                cmd << "perl Build.PL #{module_build_verbosity} && ./Build manifest #{module_build_verbosity}"
                cmd << "./Build dist #{module_build_verbosity}"
                cmd << "rm -rf #{workspace}/build/"
                cmd << "mkdir #{workspace}/build"
                cmd << "mv *.gz #{workspace}/build/"
                cmd << "rm -rf *.gz"
                cmd << "rm -rf ./cpanlib"
                build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

                distroname = File.basename(Dir.glob("#{workspace}/build/*.tar.gz").last)

                # basename of distributive will be added to artifatcs
                distro_url = "#{env['JENKINS_URL']}/job/#{job}/#{build_number}/artifact/build/#{distroname}"
                File.open("#{workspace}/build/disro.url", 'w') { |f| f.write(distro_url) }
                listener.info "distro.url: #{distro_url}"
            end
            # add notes files
            if File.exists? "#{workspace}/notes.markdown" 
                listener.info "add to artifacts notes.markdown"
                cmd = []
                cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
                cmd << "cp #{workspace}/notes.markdown #{workspace}/build/"
                build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0
            end

            # patches file
            File.open("#{workspace}/build/patches.txt", 'w') {|f| f.write(@patches) }


        end # if @enabled == true

    end

end
