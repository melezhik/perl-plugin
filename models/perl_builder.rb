require "versionomy"
require 'erb'
###
    
class PerlBuilder < Jenkins::Tasks::Builder

    attr_accessor :attrs, :run_build, :verbosity_type, :catalyst_debug, :skip_last_tag, :patches, :chef_json_template

    display_name "Build perl project" 

    # Invoked with the form parameters when this extension point
    # is created from a configuration screen.
    def initialize(attrs = {})
        @attrs = attrs
        @run_build = attrs["run_build"]
        @verbosity_type = attrs["verbosity_type"]
        @catalyst_debug = attrs["catalyst_debug"]
        @skip_last_tag = attrs["skip_last_tag"]
        @patches = attrs["patches"] || ""
        @chef_json_template = attrs["chef_json_template"]
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
        listener.info("plugin input parameters: #{@attrs}")
        listener.info("verbosity_type: #{@verbosity_type}")
        listener.info("run_build: #{@run_build}")
        workspace = build.send(:native).workspace.to_s
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
        if @run_build == true 
            # setup verbosity  
            if @verbosity_type == 'high'
                File.open("#{workspace}/modulebuildrc", 'w') {|f| f.write("test verbose=1") }
            else  
                File.open("#{workspace}/modulebuildrc", 'w') {|f| f.write("test verbose=0") }
            end      
                
            # apply patches
            @patches.split("\n").map {|l| l.chomp }.reject {|l| l.nil? || l.empty? || l =~ /^\s+#/ || l =~ /^#/ }.map{ |l| l.sub(/#.*/){""} }.each do |l|
                listener.info "apply patch: #{l}"
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

            Dir.glob("#{workspace}/svn/*").select {|f| File.directory? f}.each do |d|

                if @skip_last_tag == true then            
                    last_tag = d
                else
                    last_tag = Dir.glob("#{d}/*").select {|f2| File.directory? f2}.sort { |x,y| 
                        Versionomy.parse(File.basename(x).sub(/.*-/){""}) <=> Versionomy.parse(File.basename(y).sub(/.*-/){""}) 
                    }.last
                end

                listener.info "building last tag: #{last_tag}"
                cmd = []
                cpan_mini_verbose = @verbosity_type == 'none' ? '' : '-v'
                
                cmd << "export CATALYST_DEBUG=1" if @catalyst_debug == true 
                cmd << "export MODULEBUILDRC=#{workspace}/modulebuildrc"
                cmd << "export LC_ALL=ru_RU.UTF-8 && cd #{last_tag}"
                cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
                cmd << "eval $(perl -Mlocal::lib=#{workspace}/cpanlib)"
                cmd << "cpanm --curl #{cpan_mini_verbose} #{cpan_source_chunk} ."
                build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0
            end  

            if @skip_last_tag == true then
                app_last_tag  = "#{workspace}/svn/app/"            
            else
                app_last_tag = Dir.glob("#{workspace}/svn/app/*").select {|f2| File.directory? f2}.sort { |x,y|
                    Versionomy.parse(File.basename(x).sub(/.*-/){""}) <=> Versionomy.parse(File.basename(y).sub(/.*-/){""}) 
                }.last
            end

            listener.info "creating distributive from last tag: #{app_last_tag}"
            cmd = []
            module_build_verbosity = ''
            if @verbosity_type == 'none' then
                module_build_verbosity = '--quiet'
            elsif @verbosity_type == 'medium' then
                module_build_verbosity = ''
            elsif @verbosity_type == 'High'
                module_build_verbosity = '--verbose'
            end

            cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
            cmd << "export PERL5LIB=#{env['PERL5LIB']}" unless ( env['PERL5LIB'].nil? || env['PERL5LIB'].empty? )
            cmd << "eval $(perl -Mlocal::lib=#{workspace}/cpanlib)"
            cmd << "cd #{app_last_tag} && rm -rf #{workspace}/build/"
            cmd << "mkdir #{workspace}/build && rm -rf *.gz"
            cmd << "perl Build.PL #{module_build_verbosity} && ./Build manifest #{module_build_verbosity} && ./Build dist #{module_build_verbosity}"
            cmd << "mv *.gz #{workspace}/build/ && cd #{workspace}/build"
            cmd << "tar -xzf *.gz --verbose && rm -rf *.gz"
            build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0


            distro_dir = Dir.glob("#{workspace}/build/*").select {|f2| File.directory? f2}.last.sub(/\/$/){""}
            build_number = build.send(:native).get_number
            artifact_dir = "#{distro_dir}-b#{build_number}"

            listener.info "create artifact directory: #{artifact_dir} from original directory: #{distro_dir}"

            cmd = []
            cmd << "export LC_ALL=#{env['LC_ALL']}" unless ( env['LC_ALL'].nil? || env['LC_ALL'].empty? )
            cmd << "cd #{distro_dir} && mkdir ./cpanlib"
            cmd << "cp -r #{workspace}/cpanlib/* ./cpanlib/"
            cmd << "mv #{distro_dir} #{artifact_dir}"
            build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0

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

            # add chef json file
            listener.info "generate chef json file"
            renderer = ERB.new(@chef_json_template)
            json_str = renderer.result

            job = build.send(:native).get_project.name

            src_link = "#{env['JENKINS_URL']}/job/#{job}/#{build_number}/artifact/build/#{File.basename(artifact_dir)}/*zip*/#{File.basename(artifact_dir)}.zip"
            listener.info "generated src link: #{src_link}"
    
            json_str.sub! '%src%', src_link
            json_str.sub! '"{','{'
            json_str.sub! '}"','}'

            File.open("#{workspace}/build/chef.json", 'w') {|f| f.write(json_str) }

        end # if @run_build == true

    end

end
