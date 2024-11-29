BLACKOPS_VERSION = '0.1'

require 'pry'
require 'blackstack-core'
require 'simple_cloud_logging'
require 'simple_command_line_parser'
require 'resolv'
require 'public_suffix'
require 'open3'
require 'shellwords'
require 'highline'
require 'terminal-table'


#require 'blackstack-nodes' 
require_relative '/home/leandro/code1/blackstack-nodes/lib/blackstack-nodes.rb'

require 'blackstack-db'
require 'contabo-client'

#module BlackStack
    module BlackOps
      @@nodes = []
      @@db = nil
      @@contabo = nil
      @@repositories = [
        'https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops'
      ]


      # Helper method to display help messages
      def self.display_help(operation:)
        case operation
        when 'migrate'
          puts <<~HELP
            Usage: migrate.rb [--config=<config_file>] [--node=<node_pattern>] [--migration_folders=folder1,folder2,...] [--postgres=username:password@address:port/database] [--param1=value1] [--param2=value2] ...
            
            Options:
              --config=<config_file>             Path to the configuration file.
              --node=<node_pattern>              Pattern to match target nodes (supports wildcards).
              --migration_folders=folder1,folder2,...  Comma-separated list of migration folders.
              --postgres=username:password@address:port/database  PostgreSQL connection parameters.
              --help, -h                          Display this help message.
          HELP
        else
          puts "No help available for operation: #{operation}"
        end
      end # self.display_help

      # Determines if the given domain has a subdomain.
      #
      # @param domain [String] The domain name to check (e.g., 'sub.example.com.ar', 'example.com', 'example.com.ar').
      # @return [Boolean] Returns `true` if a subdomain exists, `false` otherwise.
      #
      # This function is for internal-use only.
      #
      def self.has_subdomain?(domain)
        begin
          # Parse the domain using PublicSuffix
          parsed_domain = PublicSuffix.parse(domain)
          
          # Extract the registrable domain (e.g., 'example.com.ar' from 'sub.example.com.ar')
          registrable_domain = parsed_domain.sld + "." + parsed_domain.tld

          # Compare the registrable domain with the input domain
          # If they are the same, there's no subdomain
          # If the input domain has more labels, it includes subdomains
          if domain.downcase == registrable_domain.downcase
            return false
          else
            # Ensure that the input domain ends with the registrable domain
            # This handles cases where the input domain might include additional labels
            if domain.downcase.end_with?(registrable_domain.downcase)
              # Count the number of labels in the input domain
              input_labels = domain.split('.').size
              registrable_labels = registrable_domain.split('.').size

              # If input has more labels than registrable domain, subdomain exists
              return input_labels > registrable_labels
            else
              # The domain does not match the expected registrable domain structure
              # Treat it as invalid or as having a subdomain
              return true
            end
          end
        rescue PublicSuffix::DomainInvalid => e
          puts "Invalid domain: #{e.message}"
          return false
        rescue PublicSuffix::DomainNotAllowed => e
          puts "Domain not allowed: #{e.message}"
          return false
        rescue StandardError => e
          puts "An error occurred: #{e.message}"
          return false
        end
      end

      # Extracts the subdomain from a given domain name.
      #
      # @param domain [String] The domain name to extract the subdomain from (e.g., 'blog.shop.example.com.ar').
      # @return [String, nil] Returns the subdomain as a string if it exists, otherwise `nil`.
      #
      # This function is for internal-use only.
      #
      def self.get_subdomain(domain)
        begin
          # Normalize the domain by removing any trailing dot and converting to lowercase
          normalized_domain = domain.strip.downcase.chomp('.')
      
          # Parse the domain using PublicSuffix
          parsed_domain = PublicSuffix.parse(normalized_domain)
      
          # Construct the registrable domain (sld + tld)
          registrable_domain = "#{parsed_domain.sld}.#{parsed_domain.tld}"
      
          # If the normalized domain is the same as the registrable domain, there's no subdomain
          return nil if normalized_domain == registrable_domain
      
          # Ensure that the domain ends with the registrable domain
          unless normalized_domain.end_with?(registrable_domain)
            # The domain does not match the expected registrable domain structure
            # It might be invalid or contain multiple subdomains; treat it as having a subdomain
            # Extract everything before the registrable domain
            subdomain_part = normalized_domain.split(registrable_domain).first.chomp('.')
            return subdomain_part.empty? ? nil : subdomain_part
          end
      
          # Extract the subdomain by removing the registrable domain from the full domain
          subdomain_part = normalized_domain[0...-registrable_domain.length].chomp('.')
      
          # Return the subdomain if it exists
          subdomain_part.empty? ? nil : subdomain_part
        rescue PublicSuffix::DomainInvalid => e
          raise "Invalid domain: #{e.message}"
        rescue PublicSuffix::DomainNotAllowed => e
          raise "Domain not allowed: #{e.message}"
        rescue StandardError => e
          raise "An error occurred: #{e.message}"
        end
      end
      
      # Resolves the IP address of a given hostname.
      #
      # @param hostname [String] The subdomain or hostname to resolve (e.g., 'sub.example.com').
      # @return [String, nil] Returns the resolved IP address as a string if successful, or `nil` if an error occurs.
      #
      # This function is for internal-use only.
      #
      def self.resolve_ip(hostname, logger: nil)
        l = logger || BlackStack::DummyLogger.new(nil)
        l.logs "Checking #{hostname.blue}... "
        begin
          # Attempt to resolve the hostname to an IP address
          ip_address = Resolv.getaddress(hostname)
          l.logf "Resolved #{hostname} to #{ip_address}."
          return ip_address
        rescue Resolv::ResolvError => e
          # Handle DNS resolution errors (e.g., hostname not found)
          l.logf "DNS resolution error for #{hostname}: #{e.message}"
          return nil
        rescue SocketError => e
          # Handle other socket-related errors
          l.logf "Socket error while resolving #{hostname}: #{e.message}"
          return nil
        rescue StandardError => e
          # Handle any other unexpected errors
          l.logf "Unexpected error while resolving #{hostname}: #{e.message}"
          return nil
        end
      end

      def self.set(
        repositories: nil,
        contabo: nil
      )
        err = []
        if repositories
          unless repositories.is_a?(Array) && repositories.all? { |rep| rep.is_a?(String) }
            err << "Invalid value for repositories. Must be an array of strings."
          end
        end # if repositories
        # TODO: Validate each string into the repositories array is a valid URL or a valid PATH with no slash (/) at the end
        # TODO: Validate contabo is an instance of ContaboClient
        raise err.join("\n") if err.size > 0
        @@repositories = repositories if repositories
        @@contabo = contabo if contabo
      end # def self.set

      def self.db
        @@db
      end

      def self.contabo
        @@contabo
      end

      def self.repositories
        @@repositories
      end

      def self.nodes
        @@nodes
      end

      def self.add_node(h)
        err = []
  
        # Set default values for optional keys if they are missing
        h[:ip] ||= nil
        h[:procs] ||= []
        h[:install_script] ||= []
        h[:deploy_script] ||= []
        h[:start_script] ||= []
        h[:stop_script] ||= []
        h[:logs] ||= []
        h[:webs] ||= []
  
        # Validate the presence and format of the mandatory keys
        if h[:name].nil? || !h[:name].is_a?(String) || h[:name].strip.empty?
          err << "Invalid value for :name. Must be a non-empty string."
        end
        
        if !h[:ip].nil?
          unless h[:ip] =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
            err << "Invalid value for :ip. Must be a valid IP address or nil."
          end
        else
          err << "IP is required."
        end

        required_ssh_keys = [:ssh_username, :ssh_port, :ssh_password, :ssh_root_password]
        required_ssh_keys.each do |key|
          if h[key].nil?
            err << "Missing required SSH key: #{key}"
          elsif key == :ssh_port
            unless h[:ssh_port].is_a?(Integer) && h[:ssh_port] > 0 && h[:ssh_port] < 65536
              err << "Invalid value for :ssh_port. Must be an integer between 1 and 65535."
            end
          elsif !h[key].is_a?(String) || h[key].strip.empty?
            err << "Invalid value for #{key}. Must be a non-empty string."
          end
        end
=begin
        if h[:db] || !h[:db].is_a?(String) || h[:db].strip.empty?
          err << "Invalid value for :db. Must be a non-empty string."
        end

        required_git_keys = [:git_repository, :git_branch, :git_username, :git_password]
        required_git_keys.each do |key|
          if h[key].nil?
            err << "Missing required Git key: #{key}"
          elsif key == :git_repository
            unless h[:git_repository].is_a?(String) && h[:git_repository].match?(/^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/)
              err << "Invalid value for :git_repository. Must be a valid GitHub repository path."
            end
          elsif !h[key].is_a?(String) || h[key].strip.empty?
            err << "Invalid value for #{key}. Must be a non-empty string."
          end
        end

        if h[:code_folder].nil? || !h[:code_folder].is_a?(String) || !h[:code_folder].start_with?('/')
          err << "Invalid value for :code_folder. Must be an absolute Linux path."
        end
=end
        # if exists, :procs must by an array of strings
        if h.key?(:procs)
          unless h[:procs].is_a?(Array) && h[:procs].all? { |proc| proc.is_a?(String) }
            err << "Invalid value for :procs. Must be an array of strings."
          end
        end # if h.key?(:procs)

        # if exists, :install_ops must by an array of strings
        if h.key?(:install_ops)
          unless h[:install_ops].is_a?(Array) && h[:install_ops].all? { |install_script| install_script.is_a?(String) }
            err << "Invalid value for :install_ops. Must be an array of strings."
          end
        end # if h.key?(:install_ops)

        # if exists, :deploy_ops must by an array of strings
        if h.key?(:deploy_ops)
          unless h[:deploy_ops].is_a?(Array) && h[:deploy_ops].all? { |deploy_script| deploy_script.is_a?(String) }
            err << "Invalid value for :deploy_ops. Must be an array of strings."
          end
        end # if h.key?(:deploy_ops)

        # if exists, :start_ops must by an array of strings
        if h.key?(:start_ops)
          unless h[:start_ops].is_a?(Array) && h[:start_ops].all? { |start_script| start_script.is_a?(String) }
            err << "Invalid value for :start_ops. Must be an array of strings."
          end
        end # if h.key?(:start_ops)

        # if exists, :stop_ops must by an array of strings
        if h.key?(:stop_ops)
          unless h[:stop_ops].is_a?(Array) && h[:stop_ops].all? { |stop_script| stop_script.is_a?(String) }
            err << "Invalid value for :stop_ops. Must be an array of strings."
          end
        end # if h.key?(:stop_ops)
  
        if h.key?(:logs)
          unless h[:logs].is_a?(Array) && h[:logs].all? { |log| log.is_a?(String) }
            err << "Invalid value for :logs. Must be an array of strings."
          end
        end
  
        if h.key?(:webs)
          unless h[:webs].is_a?(Array)
            err << "Invalid value for :webs. Must be an array of websites."
          end
  
          h[:webs].each do |web|
            unless web.is_a?(Hash) && web[:name].is_a?(String) && !web[:name].strip.empty? &&
                   web[:port].is_a?(Integer) && web[:port] > 0 && web[:port] < 65536 &&
                   [:http, :https].include?(web[:protocol])
              err << "Invalid web configuration. Each must be a hash with :name, :port, and :protocol."
            end
          end
        end
  
        # Raise exception if any errors were found
        raise ArgumentError, "The following errors were found in node descriptor: \n#{err.map { |s| " - #{s}" }.join("\n")}" unless err.empty?
  
        # Create and add the node
        @@nodes << h
      end # def self.add_node(h)
  
      # Return a duplication of the hash descriptor of the node with the given name
      def self.get_node(node_name)
        @@nodes.find { |n| n[:name].to_s == node_name.to_s }.clone
      end # def self.get_node(node_name)

      # Returns an array of hashes with IP as the key for easy lookup from nodes and instances
      # - Merge the arrays `instances` and `nodes` into one single array `all`.
      # - The key to merge both arrays is the IPv4 on each element.
      def self.merged(name_search: nil, logger: nil)
        x = name_search
        l = logger || BlackStack::DummyLogger.new(nil)
        page_size = 10
        l.logs "Bring Contabo instances (page 1)... "
        contabo = BlackOps.contabo
        if contabo.nil?
            l.skip(details: 'connection not defined')
        else
            ret = contabo.get_instances #(search: x)
            total_pages = ret['_pagination'] ? ret['_pagination']['totalPages'] : 0 
            instances = ret['data']
            if instances.nil? || !instances.is_a?(Array)
                l.logf("error (code: #{ret['statusCode'].to_s.red} - description: #{ret['message'].to_s.red})")
                exit(1)
            else
                l.done(details: 'total: ' + instances.size.to_s.blue)
    
                page = 1
                while page < total_pages
                    page += 1
                    l.logs "Bring Contabo instances (page #{page})... "
                    ret = contabo.get_instances(page: page) #, search: x)
                    instances += ret['data']        
                    l.done(details: 'total: ' + instances.size.to_s.blue)
                end
            end
        end
    
        # list of nodes defined in the configuration file
        l.logs "Get nodes defined in configuration... "
        nodes = BlackOps.nodes
        if x
          if x.include?('*') || x.include?('?') || x.include?('[')
            # Use File.fnmatch to match node names
            nodes.select! { |node| File.fnmatch(x, node[:name]) }
          else
            nodes.select! { |n| n[:name] == x }
          end
        end # if x
        l.done(details: 'total: ' + nodes.size.to_s.blue)
    
        # Example of an element into the `instances` array:
        #
        # {"tenantId"=>"INT",
        # "customerId"=>"11833581",
        # "additionalIps"=>[],
        # "name"=>"vmi2040731",
        # "displayName"=>"",
        # "instanceId"=>202040731,
        # "dataCenter"=>"European Union 4",
        # "region"=>"EU",
        # "regionName"=>"European Union",
        # "productId"=>"V45",
        # "imageId"=>"db1409d2-ed92-4f2f-978e-7b2fa4a1ec90",
        # "ipConfig"=>
        #  {"v4"=>
        #    {"ip"=>"195.179.229.21",
        #     "gateway"=>"195.179.228.1",
        #     "netmaskCidr"=>22},
        #   "v6"=>
        #    {"ip"=>"2a02:c202:2204:0731:0000:0000:0000:0001",
        #     "gateway"=>"fe80::1",
        #     "netmaskCidr"=>64}},
        # "macAddress"=>"00:50:56:53:da:3b",
        # "ramMb"=>6144,
        # "cpuCores"=>4,
        # "osType"=>"Linux",
        # "diskMb"=>409600,
        # "createdDate"=>"2024-07-24T02:28:21.000Z",
        # "cancelDate"=>"2024-10-23",
        # "status"=>"running",
        # "vHostId"=>24205,
        # "vHostNumber"=>27676,
        # "vHostName"=>"m27676",
        # "addOns"=>[],
        # "productType"=>"ssd",
        # "productName"=>"VPS 1 SSD (no setup)",
        # "defaultUser"=>"root"}
        #
        # Examples of an element into the `nodes` array:
        # 
        # {:name=>"master",
        # :ip=>"91.230.110.43",
        # :db=>"master",
        # :domain=>"leadshype.com",
        # :ssh_username=>"blackstack",
        # :ssh_port=>22,
        # :ssh_password=>"SanCristobal943",
        # :ssh_root_password=>"retert5564mbmb",
        # :git_repository=>"leandrosardi/my.saas",
        # :git_branch=>"main",
        # :git_username=>"leandrosardi",
        # :git_password=>"******************************",
        # :install_ops=>["install.ubuntu_20_04"],
        # :postgres_password=>"lgt546.ktrABGR",
        # :code_folder=>"/home/blackstack/code1/master",
        # :deploy_ops=>["mass.master.deploy"],
        # :start_ops=>["mass.master.start"],
        # :stop_ops=>["mass.master.stop"],
        # :migration_folders=>
        #  ["/home/leandro/code1/master/sql",
        #   "/home/leandro/code1/master/extensions/content/sql",
        #   "/home/leandro/code1/master/extensions/dropbox-token-helper/sql",
        #   "/home/leandro/code1/master/extensions/filtersjs/sql",
        #   "/home/leandro/code1/master/extensions/i2p/sql",
        #   "/home/leandro/code1/master/extensions/monitoring/sql",
        #   "/home/leandro/code1/master/extensions/selectrowsjs/sql",
        #   "/home/leandro/code1/master/extensions/filteersjs/sql",
        #   "/home/leandro/code1/master/extensions/mass.commons/sql",
        #   "/home/leandro/code1/master/extensions/mass.account/sql"],
        # :procs=>["launch.rb port=3000"],
        # :logs=>["/home/blackstack/code1/my.saas/app.log"],
        # :webs=>
        #  [{:name=>"ruby-sinatra", :port=>3000, :protocol=>:http},
        #   {:name=>"nginx", :port=>443, :protocol=>:https}],
        # :install_script=>[],
        # :deploy_script=>[],
        # :start_script=>[],
        # :stop_script=>[]}
        #     
        all = nodes.map { |node| { :node => node } }
        if instances
          instances.each { |instance|
              # Get the IPv4 address from the instance
              ip = instance.dig('ipConfig', 'v4', 'ip')
              # get the all record where there is a node with the same ip
              h = all.select { |h| h[:node] && h[:node][:ip] == ip }.first
              if h
                  h[:instance] = instance
              else
                  all << { :instance => instance } if x.nil?
              end
          }
        end # if
    
        all
      end

      # Downloads the `.op` file from the repositories or directly from a path or URL.
      def self.download_op_file(op, logger)
        l = logger || BlackStack::DummyLogger.new(nil)
        bash_script = nil

        # 1. Remove '.op' from the end of the 'op' parameter if it exists
        op = op.sub(/\.op\z/, '')

        # 2. Try to find the file in the repositories
        @@repositories.each do |rep|
          if rep =~ /^http/i
            url = "#{rep}/#{op}.op"
            l.logs "Downloading bash script from #{url.blue}... "
            begin
              response = Net::HTTP.get_response(URI(url))
              if response.is_a?(Net::HTTPSuccess)
                bash_script = response.body
                l.done(details: "#{bash_script.length} bytes downloaded")
                break
              else
                l.logf("Failed to download from #{url}: #{response.code} #{response.message}")
              end
            rescue => e
              l.logf("Error accessing #{url}: #{e.message}")
            end
          else
            filename = File.join(rep, "#{op}.op")
            l.logs "Getting bash script from #{filename.blue}... "
            if File.exist?(filename)
              bash_script = File.read(filename)
              l.done(details: "#{bash_script.length} bytes in file")
              break
            else
              l.logf("File not found: #{filename}")
            end
          end
        end

        # 3. If bash_script is still nil, try to load op as a full path or URL
        if bash_script.nil?
          # Try as a local file path
          if File.exist?("#{op}.op")
            l.logs "Getting bash script from #{"#{op}.op".blue}... "
            bash_script = File.read("#{op}.op")
            l.done(details: "#{bash_script.length} bytes in file")
          else
            # Try as a URL
            if op =~ /^http/i
              l.logs "Downloading bash script from #{"#{"#{op}.op"}.op".blue}... "
              begin
                response = Net::HTTP.get_response(URI("#{op}.op"))
                if response.is_a?(Net::HTTPSuccess)
                  bash_script = response.body
                  l.done(details: "#{bash_script.length} bytes downloaded")
                else
                  l.logf("Failed to download from #{"#{op}.op"}: #{response.code} #{response.message}")
                end
              rescue => e
                l.logf("Error accessing #{"#{op}.op"}: #{e.message}")
              end
            else
              l.logf("File not found and not a valid URL: #{"#{op}.op"}")
            end
          end
        end

        # Handle case when bash_script is nil (file not found)
        if bash_script.nil?
          raise "Could not find the .op file '#{op}.op' in any repository, nor as a full path or URL."
        end

        bash_script
      end

      # Extracts parameters used in the `.op` file (e.g., $$param).
      def self.extract_parameters_from_script(bash_script)
        bash_script.scan(/\$\$([a-zA-Z_][a-zA-Z0-9_]*)/).flatten.uniq
      end

      # Checks for missing parameters required by the `.op` file.
      def self.check_missing_parameters(params, param_values, error_message_prefix)
        missed = params.reject { |key| param_values.key?(key.to_sym) || param_values.key?(key.to_s) }
        unless missed.empty?
          raise ArgumentError, "#{error_message_prefix}: #{missed.join(', ')}."
        end
      end

      # Executes the script fragments by replacing parameters and running the fragments.
      def self.execute_script_fragments(bash_script, params, param_values, execute_fragment_proc, logger)
        l = logger || BlackStack::DummyLogger.new(nil)
        bash_script.split(/(?<!#)RUN /).each do |fragment|
          fragment.strip!
          next if fragment.empty?
          next if fragment.start_with?('#')

          l.logs "#{fragment.split(/\n/).first.to_s.strip[0..35].blue.ljust(57, '.')}... "

          # Remove all lines starting with `#`
          fragment = fragment.lines.reject { |line| line.strip.start_with?('#') }.join

          # Replace parameters in the fragment
          params.each do |key|
            value = param_values[key.to_sym] || param_values[key.to_s]
            fragment.gsub!("$$#{key.to_s}", value.to_s)
          end

          # Execute the fragment using the provided execute_fragment_proc
          execute_fragment_proc.call(fragment)
          l.done
        end
      end

      # Static method to look for BlackOpsFile into any of the paths defined in the environment variable $OPSLIB and load it.
      def self.load_blackopsfile(logger: nil)
        l = logger || BlackStack::DummyLogger.new(nil)
        # If config_file is not defined, look for a file named 'BlackOpsFile' in the directories specified by $OPSLIB
        opslib = ENV['OPSLIB']
        if opslib
          found = false
          opslib.split(':').each do |dir|
            filename = File.join(dir, 'BlackOpsFile')
            if File.exist?(filename)
              l.logs "Loading configuration from #{filename}..."
              load filename
              found = true
              l.done
              break
            end
          end
          #unless found
          #  raise "No configuration file found in $OPSLIB directories. Please provide a --config option or set up $OPSLIB environment variable correctly."
          #end
        #else
        #  raise "No configuration file specified and $OPSLIB environment variable is not set. Please provide a --config option or set up $OPSLIB."
        end
      end

      def self.source_remote(
        node_name,
        op:,
        parameters: {},
        connect_as_root: false,
        logger: nil
      )
        op = op.to_s
        node = nil
        begin
          l = logger || BlackStack::DummyLogger.new(nil)
          node_name = node_name.dup.to_s
      
          l.logs "Getting node #{node_name.blue}... "
          n0 = get_node(node_name)
          n = n0.clone
          raise ArgumentError, "Node not found: #{node_name}" if n.nil?
          l.done
      
          # Remove :name from node descriptor if it's "__temp_node_unique_name__"
          if n[:name] == "__temp_node_unique_name__"
            n.delete(:name)
          end
      
          # Validate that parameters is a hash
          raise ArgumentError, "Parameters must be a hash" unless parameters.is_a?(Hash)
      
          # Check for overlapping keys between node parameters and provided parameters
          overlapping_keys = parameters.keys.map(&:to_s) & n.keys.map(&:to_s)
          if overlapping_keys.any?
            raise ArgumentError, "Parameters defined in both node and parameters argument: #{overlapping_keys.join(', ')}"
          end
      
          # Merge parameters into node parameters
          parameters.each do |k, v|
            n[k.to_sym] = v
          end
      
          # Download the `.op` file from the repository
          bash_script = download_op_file(op, l)
      
          # Extract parameters used in the `.op` file (e.g., $$param)
          params = extract_parameters_from_script(bash_script)
      
          # Check for missing parameters required by the `.op` file
          check_missing_parameters(params, n, "Missing parameters required by the op #{op.to_s}")
      
          # Create the node object with the appropriate SSH credentials
          l.logs "Creating node object... "
          backup_ssh_username = nil
          backup_ssh_password = nil
          if connect_as_root
            backup_ssh_username = n[:ssh_username]
            backup_ssh_password = n[:ssh_password]
  
            n[:ssh_username] = 'root'
            n[:ssh_password] = n[:ssh_root_password]

            node = BlackStack::Infrastructure::Node.new(n)
          else
            node = BlackStack::Infrastructure::Node.new(n)
          end
          l.done
          
          # Connect to the remote node via SSH
          l.logs("Connect to node #{node_name.to_s.blue}... ")
          node.connect
          n[:ssh_username] = backup_ssh_username if backup_ssh_username
          n[:ssh_password] = backup_ssh_password if backup_ssh_password
          l.done
      
          # Prepare the execution lambda
          execute_fragment_proc = Proc.new { |fragment|
            res = node.exec(fragment)
          }
      
          # Execute the script fragment by fragment
          execute_script_fragments(bash_script, params, n, execute_fragment_proc, l)
      
        rescue => e
          raise e
        ensure
          # Disconnect from the remote node
          l.logs "Disconnect from node #{node_name.blue}... "
          if node && node.ssh
            node.disconnect
            l.done
          else
            l.skip(details: "Node not connected")
          end
        end
      end

      def self.source_local(
        op:,
        parameters: {},
        logger: nil
      )
        begin
          l = logger || BlackStack::DummyLogger.new(nil)
          op = op.to_s
      
          # Validate that parameters is a hash
          raise ArgumentError, "Parameters must be a hash" unless parameters.is_a?(Hash)
      
          # Download the `.op` file from the repositories
          bash_script = download_op_file(op, l)
      
          # Extract parameters used in the `.op` file (e.g., $$param)
          params = extract_parameters_from_script(bash_script)
      
          # Check for missing parameters required by the `.op` file
          check_missing_parameters(params, parameters, "Missing parameters required by the op #{op.to_s}")
      
          # Prepare the execution lambda
          execute_fragment_proc = Proc.new { |fragment|
            require 'open3'
            stdout, stderr, status = Open3.capture3(fragment)
      
            if status.success?
              # Do nothing; success is handled outside
            else
              l.error "Command failed with status #{status.exitstatus}: #{stderr.strip}"
              raise "Command failed: #{fragment}"
            end
          }
      
          # Execute the script fragment by fragment
          execute_script_fragments(bash_script, params, parameters, execute_fragment_proc, l)
      
        rescue => e
          # l.error "An error occurred: #{e.message}".red
          raise e
        end
      end      

      # 
      def self.ssh(
        node_name,
        connect_as_root: false,
        logger: nil
      )
        l = logger || BlackStack::DummyLogger.new(nil)
        node_name = node_name.dup.to_s

        l.logs "Getting node #{node_name.blue}... "
        n = get_node(node_name)
        raise ArgumentError, "Node not found: #{node_name}" if n.nil?
        l.done

        # switch user to root and create the node object
        l.logs "Creating node object... "
        if connect_as_root
          n[:ssh_username] = 'root'
          n[:ssh_password] = n[:ssh_root_password]
          node = BlackStack::Infrastructure::Node.new(n)
        else
          node = BlackStack::Infrastructure::Node.new(n)
        end
        l.done

        # TODO: move this to the node class
        # if the node has a key, use it
        s = nil
        if node.ssh_private_key_file
            s = "ssh -o StrictHostKeyChecking=no -i \"#{Shellwords.escape(node.ssh_private_key_file)}\" #{node.ssh_username}@#{node.ip} -p #{node.ssh_port}"
        else
            # DEPRECATED: This is not working, because it is escaping the #
            #escaped_password = Shellwords.escape(node.ssh_private_key_file)
            escaped_password = node.ssh_password.gsub(/\$/, "\\$")
            #s = "sshpass -p \"#{escaped_password}\" ssh -o KbdInteractiveAuthentication=no -o PasswordAuthentication=yes -o PreferredAuthentications=password -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o BatchMode=yes -o UserKnownHostsFile=/dev/null #{node.ssh_username}@#{node.ip} -p #{node.ssh_port}"
            s = "sshpass -p \"#{escaped_password}\" ssh -o StrictHostKeyChecking=no #{node.ssh_username}@#{node.ip} -p #{node.ssh_port}"
        end

        #t = "ssh-keygen -f \"#{ENV['HOME']}/.ssh/known_hosts2\" -R \"#{n[:ip].to_s}\""
        #l.log "Command: #{t.blue}"
        #system(t)

        l.log "Command: #{s.blue}"
        system(s)
      end # def self.ssh(node_name, logger: nil)  

=begin
      # Return the hash descriptor of a contabo instance from its IP address.
      def self.get_instance(
        node_name,
        logger: nil
      )
        ret = nil
        l = logger || BlackStack::DummyLogger.new(nil)
        node_name = node_name.dup.to_s

        l.logs "Getting node #{node_name.blue}... "
        n = get_node(node_name)
        raise ArgumentError, "Node not found: #{node_name}" if n.nil?
        l.done

        l.logs "Get the IP of the node #{node_name.blue}... "
        ip = n[:ip]
        l.done(details: ip.to_s.blue)

        l.logs "Getting Contabo client... "
        client = self.contabo
        raise "Contabo client is not configured" if client.nil?
        l.done

        l.logs 'Getting pages... '
        p = 1
        z = 100
        json = client.get_instances(page: p, size: z)
        if json['data'].nil? || !json['data'].is_a?(Array)
          raise "No instances returned or unexpected data format. Response: #{json.inspect}"
        end
        total_pages = json['_pagination']['totalPages']
        l.done(details: total_pages.to_s.blue)

        while !ret && total_pages >= p
          l.logs "Fetching page #{p.to_s.blue}/#{total_pages.to_s.blue}... "  
          json = client.get_instances(page: p, size: z)
          if json['data'].nil? || !json['data'].is_a?(Array)
            raise "No instances returned or unexpected data format. Response: #{json.inspect}"
          end
          ret = json['data'].find { |h| ip == h.dig('ipConfig', 'v4', 'ip') }
          p += 1
          l.done(details: ret ? 'found'.green : 'not found'.yellow)
        end # while json['_pagination']['totalPages']

        ret
      end # def self.get_instance(node_name, logger: nil)  

      # Request the reinstallation of a node to Contabo.
      def self.reinstall(
        node_name,
        logger: nil
      )
        ret = nil
        l = logger || BlackStack::DummyLogger.new(nil)
        node_name = node_name.dup.to_s

        l.logs "Getting node #{node_name.blue}... "
        n = get_node(node_name)
        raise ArgumentError, "Node not found: #{node_name}" if n.nil?
        l.done

        l.logs "Getting Contabo client... "
        client = self.contabo
        raise "Contabo client is not configured" if client.nil?
        l.done

        l.logs "Loading instance... "
        inst = BlackOps.get_instance( node_name,
              logger: nil #l
        )
        raise "Instance not found." if inst.nil?
        l.done
        
        instance_id = inst['instanceId']

        l.logs "Getting instance image... "
        image_id = inst['imageId']
        raise 'Image not found' if image_id.nil?
        l.done 

        l.logs "Getting instance id... "
        instance_id = inst['instanceId']
        l.done

        user_data_script = <<~USER_DATA
          #cloud-config
          disable_cloud_init: true
          runcmd:
            - touch /etc/cloud/cloud-init.disabled
            - systemctl stop cloud-init
            - systemctl disable cloud-init
        USER_DATA
      
        # Request reinstallation
        ret = client.reinstall_instance(
          instance_id: instance_id,
          image_id: image_id,
          root_password: n[:ssh_root_password],
          user_data: user_data_script
        )

        ret
      end # def self.reinstall
=end
      def self.standard_operation_bundle(
        arguments: ,
        operation_bundle_name: ,
        logger: nil
      )
        l = logger || BlackStack::DummyLogger.new(nil)

        # Initialize variables
        config_file = nil
        node_pattern = nil
        ssh_credentials = nil
        local = false
        connect_as_root = false
        parameters = {}
        ops = nil

        # Process command-line arguments
        arguments.each do |arg|
          case arg
          when '--root'
            connect_as_root = true
          when '--local'
            local = true
          when /^--config=(.+)$/
            config_file = $1
          when /^--node=(.+)$/
            node_pattern = $1
          when /^--ssh=(.+)$/
            ssh_credentials = $1
          when /^--#{operation_bundle_name}_ops=(.+)$/
            ops = $1.split(',')
          when /^--(\w+)=(.*)$/
            key = $1
            value = $2
            parameters[key] = value
          else
            puts "Unknown argument: #{arg}"
            puts "Usage: #{operation_bundle_name}.rb [--config=<config_file>] [--node=<node_pattern>] [--ssh=<ssh_credentials>] [--local] [--root] [--#{operation_bundle_name}_ops=op1,op2,...] [--param1=value1] [--param2=value2] ..."
            exit 1
          end
        end

        # Load the configuration file
        if config_file
          load config_file
        else
          # Look for BlackOpsFile in any of the paths defined in the environment variable $OPSLIB
          BlackOps.load_blackopsfile
        end


        nodes_list = []
        
        if local
          # Local execution
          if ops.nil?
            puts "Error: --#{operation_bundle_name}_ops is required when using --local."
            puts "Usage: #{operation_bundle_name}.rb --local --#{operation_bundle_name}_ops=op1,op2,... [--param1=value1] [--param2=value2] ..."
            exit 1
          end

          ops.each do |op_file|
            l.logs "Executing #{op_file.blue} locally..."
            BlackOps.source_local(
              op: op_file,
              parameters: parameters,
              logger: l
            )
            l.done
          end

        else
          # Remote operation
          if node_pattern
            # Determine if the node_pattern contains wildcards
            if node_pattern.include?('*') || node_pattern.include?('?') || node_pattern.include?('[')
              # Use File.fnmatch to match node names
              nodes_list = BlackOps.nodes.select { |node| File.fnmatch(node_pattern, node[:name]) }

              if nodes_list.empty?
                raise "No nodes match the pattern '#{node_pattern}'."
              end
            else
              # No wildcard, process a single node
              # Check if the node exists
              if !BlackOps.nodes.any? { |node| node[:name] == node_pattern }
                raise "Node not found: #{node_pattern}"
              end

              nodes_list << BlackOps.nodes.select { |node| node[:name] == node_pattern }.first
            end
          elsif ssh_credentials
            # Parse ssh_credentials to create a temporary node
            # Expected format: username:password@ip:port
            match = ssh_credentials.match(/^([^:]+):([^@]+)@([\d\.]+):(\d+)$/)
            if match
              username = match[1]
              password = match[2]
              ip = match[3]
              port = match[4].to_i

              # Create a temporary node hash
              node_hash = {
                name: '__temp_node_unique_name__',
                ip: ip,
                ssh_username: username,
                ssh_password: password,
                ssh_root_password: password, # Assuming same password
                ssh_port: port
              }

              # If using --ssh, then --#{operation_bundle_name}_ops is required
              if ops.nil?
                  puts "Error: --#{operation_bundle_name}_ops is required when using --ssh."
                  puts "Usage: #{operation_bundle_name}.rb --ssh=<ssh_credentials> --#{operation_bundle_name}_ops=op1,op2,... [--param1=value1] [--param2=value2] ..."
                  exit 1
              end
              node_hash["#{operation_bundle_name}_ops".to_sym] = ops

              # Add the node to BlackOps nodes
              BlackOps.add_node(node_hash)

              # Retrieve the node
              nodes_list << BlackOps.get_node('__temp_node_unique_name__')
            else
              puts "Invalid SSH credentials format. Expected username:password@ip:port"
              exit 1
            end
          else
            puts "Error: You must specify either --node=<node_pattern> or --ssh=<ssh_credentials> or --local"
            puts "Usage: #{operation_bundle_name}.rb [--config=<config_file>] [--node=<node_pattern>] [--ssh=<ssh_credentials>] [--local] [--root] [--#{operation_bundle_name}_ops=op1,op2,...] [--param1=value1] [--param2=value2] ..."
            exit 1
          end

          # Iterate over the list of .op files and execute them
          nodes_list.each do |node|
              l.logs "Working on node #{node[:name].to_s.blue}... " 

              # Merge parameters into node parameters (parameters take precedence)
              parameters.each do |k, v|
                  node[k.to_sym] = v unless k.to_sym==:name && node[k.to_sym]=='__temp_node_unique_name__'
              end

              # Get the list of .op files from the node's description
              ops_list = node["#{operation_bundle_name}_ops".to_sym]
              if ops_list.nil? || !ops_list.is_a?(Array) || ops_list.empty?
                  raise "No .op files specified in the node's :#{operation_bundle_name}_ops list."
              end
          
              ops_list.each do |op_file|
                  l.logs "Executing #{op_file.blue} on node #{node[:name].blue}..."
                  BlackOps.source_remote(
                      node[:name],
                      op: op_file,
                      parameters: parameters,
                      connect_as_root: connect_as_root,
                      logger: l
                  )
                  l.done
              end

              # Installing node...
              l.done
          end
        end
      end # def self.standard_operation_bundle


      # Process one by one the `.sql` files inside the migration folders, 
      # running one by one the SQL sentences inside each file.
def self.run_migrations(node_name, logger: nil)
  l = logger || BlackStack::DummyLogger.new(nil)
  node_name = node_name.dup.to_s

  l.logs "Getting node #{node_name.blue}... "
  node = get_node(node_name)
  raise ArgumentError, "Node not found: #{node_name}" if node.nil?
  l.done

  # Initialize SSH connection
  l.logs "Establishing SSH connection to node #{node_name.blue}... "
  infra_node = BlackStack::Infrastructure::Node.new(node)
  infra_node.connect
  l.done

  begin
    # Iterate over each migration folder
    node[:migration_folders].each do |migrations_folder|
      l.logs "Listing SQL files in remote folder #{migrations_folder.blue}... "

      # List all .sql files in the remote migration folder
      list_command = "find #{Shellwords.escape(migrations_folder)} -type f -name '*.sql' | sort"
      remote_sql_files = infra_node.exec(list_command)

      if remote_sql_files.nil? || remote_sql_files.empty?
        l.logf "No SQL files found in #{migrations_folder.blue}."
        next
      end

      # Split the output into an array of file paths
      sql_files = remote_sql_files.split("\n").map(&:strip).reject(&:empty?)

      l.done(details: "#{sql_files.size} SQL file(s) found.")

      sql_files.each do |remote_file|
        l.logs "Processing #{remote_file.blue} on node #{node_name.blue}... "

        begin
          # Read the content of the SQL file remotely
          l.logs "Reading SQL file #{remote_file.blue}... "
          sql_content = infra_node.exec("cat #{Shellwords.escape(remote_file)}")
          l.done

          # Split the SQL content into individual statements
          l.logs "Splitting SQL statements... "
          statements = sql_content.split(/;/).map(&:strip).reject { |stmt| stmt.empty? || stmt.start_with?('--') }
          l.done(details: "#{statements.size} statement(s) found.")

          # Execute statements in batches of batch_size
          batch_size = 200
          statements.each_slice(batch_size).with_index do |batch, batch_index|
            # Calculate the range of statements in the current batch
            start_index = batch_index * batch_size + 1
            end_index = start_index + batch.size - 1

            l.logs "Executing statements #{start_index} to #{end_index}/#{statements.size} in batch #{batch_index + 1}... "
            begin
              # Concatenate the batch of statements with semicolons and newlines
              batch_sql = batch.join(";\n") + ";" # Ensure the last statement ends with a semicolon

              # Create a unique temporary file name
              temp_file = "/tmp/migration_batch_#{batch_index + 1}_#{Time.now.to_i}.sql"

              # Upload the batch_sql to the temporary file on the remote server
              #l.logs "Uploading batch SQL to #{temp_file}... "
              upload_command = "echo -e #{Shellwords.escape(batch_sql)} > #{temp_file}"
              infra_node.exec(upload_command)
              #l.done

              # Retrieve PostgreSQL credentials
              postgres_username = Shellwords.escape(node[:postgres_username])
              postgres_password = Shellwords.escape(node[:postgres_password])
              postgres_database = Shellwords.escape(node[:postgres_database])

              # Construct the psql command with PGPASSWORD and execute the temporary SQL file
              psql_command = "export PGPASSWORD=#{postgres_password} && psql -U #{postgres_username} -d #{postgres_database} -f #{Shellwords.escape(temp_file)}"
              
              # Execute the SQL batch
              #l.logs "Executing batch #{batch_index + 1}... "
              ret = infra_node.exec(psql_command)
              #l.done(details: "Batch #{batch_index + 1} executed successfully.")

              # Remove the temporary SQL file
              #l.logs "Removing temporary file #{temp_file}... "
              infra_node.exec("rm #{Shellwords.escape(temp_file)}")
              #l.done

              l.done

            rescue => e
              # Log the error with batch details
              l.logf "Error executing batch #{batch_index + 1} (statements #{start_index} to #{end_index}): #{e.message}".red

              # Raise an exception to halt the migration process
              raise "Error executing migration batch #{batch_index + 1}: #{e.message}"
            end
          end

        rescue => e
          l.logf(e.to_console.red)
          raise "Error processing migration file: #{remote_file}\n#{e.message}"
        end

        l.done
      end
    end

    l.log "Migrations completed on node #{node_name.blue}."
    #l.done

  rescue => e
    l.log(e.to_console.red)
    raise e
  ensure
    # Ensure SSH connection is closed
    if infra_node && infra_node.connected?
      l.logs "Closing SSH connection to node #{node_name.blue}... "
      infra_node.disconnect
      l.done
    end
  end
end

      # Static method to handle migration operations
      def self.standard_migrations_processing(
        arguments:,
        logger: nil
      )
        l = logger || BlackStack::DummyLogger.new(nil)

        # Initialize variables
        config_file = nil
        node_pattern = nil
        migration_folders = nil
        postgres = nil
        node_names = []

        # Process command-line arguments
        arguments.each do |arg|
          case arg
          when /^--config=(.+)$/
            config_file = Regexp.last_match(1)
          when /^--node=(.+)$/
            node_pattern = Regexp.last_match(1)
          when /^--migration_folders=(.+)$/
            migration_folders = Regexp.last_match(1).split(',').map(&:strip)
          when /^--postgres=(.+)$/
            postgres = Regexp.last_match(1)
          when '--help', '-h'
            display_help(operation: 'migrate')
            exit 0
          else
            puts "Unknown argument: #{arg}"
            puts "Usage: migrate.rb [--config=<config_file>] [--node=<node_pattern>] [--migration_folders=folder1,folder2,...] [--postgres=username:password@address:port/database] [--param1=value1] [--param2=value2] ..."
            exit 1
          end
        end

        # Validate required arguments
        if node_pattern.nil? && (migration_folders.nil? || postgres.nil?)
          puts "Error: When --node is not specified, --migration_folders and --postgres are required."
          puts "Usage: migrate.rb [--config=<config_file>] [--node=<node_pattern>] [--migration_folders=folder1,folder2,...] [--postgres=username:password@address:port/database] [--param1=value1] [--param2=value2] ..."
          exit 1
        end

        # Load the configuration file
        if config_file
          unless File.exist?(config_file)
            raise "Configuration file not found: #{config_file}"
          end
          l.logs "Loading configuration from #{config_file}..."
          load config_file
          l.done
        else
          # Look for BlackOpsFile in any of the paths defined in the environment variable $OPSLIB
          BlackOps.load_blackopsfile(logger: l)
        end

        # Determine target nodes or set up database connection
        if node_pattern
          # Node-based migration
          # Determine if the node_pattern contains wildcards
          if node_pattern.include?('*') || node_pattern.include?('?') || node_pattern.include?('[')
            # Use File.fnmatch to match node names
            matched_nodes = BlackOps.nodes.select { |node| File.fnmatch(node_pattern, node[:name]) }

            if matched_nodes.empty?
              raise "No nodes match the pattern '#{node_pattern}'."
            end
          else
            # No wildcard, process a single node
            matched_nodes = BlackOps.nodes.select { |node| node[:name] == node_pattern }
            if matched_nodes.empty?
              raise "Node not found: #{node_pattern}"
            end
          end

          # Extract node names
          node_names = matched_nodes.map { |node| node[:name] }

          # Run migrations on each node
          node_names.each do |node_name|
            l.logs "Running migrations on node #{node_name.blue}... "
            BlackOps.run_migrations(node_name, logger: l)
            l.done
          end

        else
          # Database-based migration
          # Validate migration_folders and postgres are provided
          if migration_folders.nil? || postgres.nil?
            puts "Error: --migration_folders and --postgres are required for database migrations."
            puts "Usage: migrate.rb [--config=<config_file>] [--node=<node_pattern>] [--migration_folders=folder1,folder2,...] [--postgres=username:password@address:port/database] [--param1=value1] [--param2=value2] ..."
            exit 1
          end

          #postgres_connection = "username:password@192.168.1.100:5432/blackstack"
          match = postgres.match(/^([^:]+):([^@]+)@([^:]+):(\d+)\/(.+)$/) or raise "Invalid PostgreSQL format. Expected username:password@address:port/database"
          postgres_username, postgres_password, postgres_address, postgres_port, postgres_database = match.captures
          postgres_port = postgres_port.to_i

          # Create a temporary node with migration_folders and postgres
          temp_node_name = '__temp_migration_node__'

          node_hash = {
            name: temp_node_name,
            migration_folders: migration_folders,
            ip: postgres_address,
            postgres_database: postgres_database,
            postgres_username: postgres_username,
            postgres_password: postgres_password,
            postgres_port: postgres_port,

            # dummy values for parameters required by blackstack-nodes
            ssh_port: 22,
            ssh_username: 'foo',
            ssh_password: 'foo',
            ssh_root_password: 'foo',
          }

          # Add the temporary node to BlackOps nodes
          BlackOps.add_node(node_hash)

          # Retrieve the temporary node
          temp_node = BlackOps.get_node(temp_node_name)

          if temp_node.nil?
            raise "Failed to create temporary migration node."
          end

          l.logs "Running migrations on temporary node #{temp_node[:name].to_s.blue}... "
          begin
            # Call the existing BlackOps.migrate method for the temporary node
            BlackOps.run_migrations(temp_node[:name], logger: l)
            l.done
          rescue => e
            l.log("Migration failed on temporary node #{temp_node[:name].to_s.red}: #{e.message}".red)
            exit 1
          end
        end
      end # def self.standard_migrations_processing
    end # BlackOps
#end # BlackStack
    