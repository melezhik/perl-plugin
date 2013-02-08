class PerlPublisher < Jenkins::Tasks::Publisher

    attr_accessor :run_deploy, :run_test, :cucumber_profile, :browser, :display
    attr_accessor :ssh_host, :ssh_login, :chef_client_config

    display_name "Deploy and test perl project"

    def initialize(attrs = {})
        @run_deploy = attrs["run_deploy"]
        @ssh_host = attrs["ssh_host"]
        @ssh_login = attrs["ssh_login"]
        @chef_client_config = attrs["chef_client_config"]
        @run_test = attrs["run_test"]
        @cucumber_profile = attrs["cucumber_profile"]
        @browser = attrs["browser"] || 'chrome'
        @display = attrs["display"]
    end

    def prebuild(build, listener)
    end

    def default_ruby_version
        '1.8.7'
    end
    def perform(build, launcher, listener)

        env = build.native.getEnvironment()

        if @run_deploy == true


            job = build.send(:native).get_project.name
            build_number = build.send(:native).get_number

            listener.info "run deploy on remote server: #{@ssh_host}"

            chef_json_uri = "#{env['JENKINS_URL']}/job/#{job}/#{build_number}/artifact/build/chef.json"

            listener.info "chef_json uri: #{chef_json_uri}"

            cmd = []
            cmd << "export LC_ALL=ru_RU.UTF-8"
            config_path = ''
            config_path = " -c #{@chef_client_config}" unless (@chef_client_config.nil? ||  @chef_client_config.empty?)
            cmd << "ssh #{@ssh_login}@#{@ssh_host} sudo chef-client -j #{chef_json_uri} #{config_path}"
            listener.info "deploy command: #{cmd.join(' && ')}"

            build.abort unless launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) == 0
        end

        if @run_test == true

            workspace = build.send(:native).workspace.to_s
            listener.info "cucumber profile: #{@cucumber_profile}"
            listener.info "run tests against remote server: #{@ssh_host}"

            test_pass_ok = true
            ruby_version = env['ruby_version'] || default_ruby_version

            Dir.glob("#{workspace}/cucumber/*").select {|f| File.directory? f}.each do |d|
                listener.info "run #{d} tests"
                cmd = []
                cmd << "export LC_ALL=ru_RU.UTF-8"
                if launcher.execute("bash", "-c", 'rvm' ) == 0
                    listener.info "found rvm configured"
                else
                    listener.info "rvm configured not found ... hope it's okay, will try to load it as {env['HOME']}/.rvm/scripts/rvm"
                    cmd << "source #{env['HOME']}/.rvm/scripts/rvm"
                end
                cmd << "export http_proxy=#{env['http_proxy']}" unless (env['http_proxy'].nil? ||  env['http_proxy'].empty?)
                cmd << "export https_proxy=#{env['http_proxy']}" unless (env['http_proxy'].nil? ||  env['http_proxy'].empty?)
                cmd << "cd #{d}"
                cmd << "rvm use #{ruby_version}"
                cmd << "bundle"
                display = ''
                display = "DISPLAY=#{@display}" unless @display.nil? || @display.empty?    
                cmd << "bundle exec cucumber -p #{@cucumber_profile} -c no_proxy=127.0.0.1 browser=#{@browser} #{display}"
                test_pass_ok = false if launcher.execute("bash", "-c", cmd.join(' && '), { :out => listener } ) != 0
            end 
            build.abort if test_pass_ok == false
        end

    end

end


