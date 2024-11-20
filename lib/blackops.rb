BLACKOPS_VERSION = '0.1'

require 'pry'
require 'blackstack-core'
require 'simple_cloud_logging'
require 'simple_command_line_parser'
require 'resolv'
require 'public_suffix'
require 'shellwords'
require 'highline'
require 'terminal-table'

#require 'blackstack-nodes' 
require_relative '/home/leandro/code1/blackstack-nodes/lib/blackstack-nodes.rb'

require 'blackstack-db'
require 'contabo-client'

#require 'namecheap-client'
require_relative '/home/leandro/code1/namecheap-client/lib/namecheap-client.rb'

#module BlackStack
    module BlackOps
      @@nodes = []
      @@db = nil
      @@namecheap = nil
      @@contabo = nil
      @@repositories = [
        'https://raw.githubusercontent.com/leandrosardi/blackops/refs/heads/main/ops'
      ]

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
        secrets_git: nil,
        secrets: nil,
        contabo: nil, 
        namecheap: nil
      )
        err = []
        if repositories
          unless repositories.is_a?(Array) && repositories.all? { |rep| rep.is_a?(String) }
            err << "Invalid value for repositories. Must be an array of strings."
          end
        end # if repositories
        # TODO: Validate each string into the repositories array is a valid URL or a valid PATH with no slash (/) at the end
        # TODO: Validate the secrets_git is a valid PATH with no slash (/) at the end
        # TODO: Validate each string into the secrets array is a valid PATH with no slash (/) at the end
        # TODO: Validate namecheap is an instance of NamecheapClient
        # TODO: Validate contabo is an instance of ContaboClient
        raise err.join("\n") if err.size > 0
        @@repositories = repositories if repositories
        @@secrets_git = secrets_git if secrets_git
        @@secrets = secrets if secrets
        @@contabo = contabo if contabo
        @@namecheap = namecheap if namecheap
      end # def self.set

      def self.namecheap
        @@namecheap
      end

      def self.contabo
        @@contabo
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
        nodes.select! { |n| n[:name] =~ /#{x}/ } if x
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

      # Parse and execute the sentences in an `.op` file on a remote node.
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
          bash_script = nil
          @@repositories.each do |rep|
            if rep =~ /^http/i
              url = "#{rep}/#{op}.op"
              l.logs "Downloading bash script from #{url.blue}... "
              # TODO: Validate if the URL exists. And return if the script is successfully retrieved.
              bash_script = Net::HTTP.get(URI(url))
              l.done(details: "#{bash_script.length} bytes downloaded")
            else
              filename = "#{rep}/#{op}.op"
              l.logs "Getting bash script from #{filename.blue}... "
              # TODO: Validate if the PATH exists. And return if the script is successfully retrieved.
              bash_script = File.read(filename)
              l.done(details: "#{bash_script.length} bytes in file")
            end
          end

          # Create the node object with the appropriate SSH credentials
          l.logs "Creating node object... "
          if connect_as_root
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
          l.done

          # Extract parameters used in the `.op` file (e.g., $$param)
          params = bash_script.scan(/\$\$([a-zA-Z_][a-zA-Z0-9_]*)/).flatten.uniq

          # Check for missing parameters required by the `.op` file
          missed = params.reject { |key| n.key?(key.to_sym) }
          unless missed.empty?
            raise ArgumentError, "Node #{node_name} is missing the following parameters required by the op #{op.to_s}: #{missed.join(', ')}."
          end

          # Execute the script fragment by fragment
          bash_script.split(/(?<!#)RUN /).each do |fragment|
            fragment.strip!
            next if fragment.empty?
            next if fragment.start_with?('#')

            l.logs "#{fragment.split(/\n/).first.to_s.strip[0..35].blue.ljust(57, '.')}... "

            # Remove all lines starting with `#`
            fragment = fragment.lines.reject { |line| line.strip.start_with?('#') }.join

            # Replace parameters in the fragment
            params.each do |key|
              fragment.gsub!("$$#{key.to_s}", n[key.to_sym].to_s)
            end

            # Execute the fragment on the remote node
            res = node.exec(fragment)
            l.done
          end
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

      # Execute the sentences in an `.op` file on the local machine.
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
          bash_script = nil
          @@repositories.each do |rep|
            if rep =~ /^http/i
              url = "#{rep}/#{op}.op"
              l.logs "Downloading bash script from #{url.blue}... "
              # TODO: Validate if the URL exists. And return if the script is successfully retrieved.
              bash_script = Net::HTTP.get(URI(url))
              l.done(details: "#{bash_script.length} bytes downloaded")
            else
              filename = "#{rep}/#{op}.op"
              l.logs "Getting bash script from #{filename.blue}... "
              # TODO: Validate if the PATH exists. And return if the script is successfully retrieved.
              bash_script = File.read(filename)
              l.done(details: "#{bash_script.length} bytes in file")
            end
          end

          # Extract parameters used in the `.op` file (e.g., $$param)
          params = bash_script.scan(/\$\$([a-zA-Z_][a-zA-Z0-9_]*)/).flatten.uniq

          # Check for missing parameters required by the `.op` file
          missed = params.reject { |key| parameters.key?(key.to_sym) || parameters.key?(key.to_s) }
          unless missed.empty?
            raise ArgumentError, "Missing parameters required by the op #{op.to_s}: #{missed.join(', ')}."
          end

          # Execute the script fragment by fragment
          bash_script.split(/(?<!#)RUN /).each do |fragment|
            fragment.strip!
            next if fragment.empty?
            next if fragment.start_with?('#')

            l.logs "#{fragment.split(/\n/).first.to_s.strip[0..35].blue.ljust(57, '.')}... "

            # Remove all lines starting with `#`
            fragment = fragment.lines.reject { |line| line.strip.start_with?('#') }.join

            # Replace parameters in the fragment
            params.each do |key|
              value = parameters[key.to_sym] || parameters[key.to_s]
              fragment.gsub!("$$#{key.to_s}", value.to_s)
            end

            # Execute the fragment locally
            require 'open3'
            stdout, stderr, status = Open3.capture3(fragment)

            if status.success?
              l.done
            else
              l.error "Command failed with status #{status.exitstatus}: #{stderr.strip}"
              raise "Command failed: #{fragment}"
            end
          end
        rescue => e
          #l.error "An error occurred: #{e.message}".red
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


      # Method to process an `.sql` file with one sql sentence by line.
      # This method is called by `migrations`. 
      # This method should not be called directly by user code.
      def self.execute_sentences(sql, 
        chunk_size: 200, 
        logger: nil
      )      
        l = logger || BlackStack::DummyLogger.new(nil)
        
        # Fix issue: Ruby `split': invalid byte sequence in UTF-8 (ArgumentError)
        # Reference: https://stackoverflow.com/questions/11065962/ruby-split-invalid-byte-sequence-in-utf-8-argumenterror
        #
        # Fix issue: `PG::SyntaxError: ERROR:  at or near "��truncate": syntax error`
        #
        l.logs "Fixing invalid byte sequences... "
        sql.encode!('UTF-8', :invalid => :replace, :replace => '')
        l.done

        # Remove null bytes to avoid error: `String contains null byte`
        # Reference: https://stackoverflow.com/questions/29320369/coping-with-string-contains-null-byte-sent-from-users
        l.logs "Removing null bytes... "
        sql.gsub!("\u0000", "")
        l.done

        # Get the array of sentences
        l.logs "Splitting the sql sentences... "
        sentences = sql.split(/;/i) 
        l.done(details: "#{sentences.size} sentences")

        # Chunk the array into parts of chunk_size elements
        # Reference: https://stackoverflow.com/questions/2699584/how-to-split-chunk-a-ruby-array-into-parts-of-x-elements
        l.logs "Bunlding the array of sentences into chunks of #{chunk_size} each... "
        chunks = sentences.each_slice(chunk_size).to_a
        l.done(details: "#{chunks.size} chunks")

        chunk_number = -1
        chunks.each { |chunk|
          chunk_number += 1
          statement = chunk.join(";\n").to_s.strip
          l.logs "lines #{(chunk_size*chunk_number+1).to_s.blue} to #{(chunk_size*chunk_number+chunk.size).to_s.blue} of #{sentences.size.to_s.blue}... "
          begin
            @@db.execute(statement) #if statement.to_s.strip.size > 0
            l.done
          rescue => e
            l.log(e.to_console.red)
            raise "Error executing statement: #{statement}\n#{e.message}"
          end
        }
      end # def db_execute_sql_sentences_file

      # Process one by one the `.sql` files inside the migration folders, 
      # running one by one the SQL sentences inside each file.
      def self.migrations(
        node_name,
        logger: nil
      )
        l = logger || BlackStack::DummyLogger.new(nil)
        node_name = node_name.dup.to_s

        l.logs "Getting node #{node_name.blue}... "
        n = get_node(node_name)
        raise ArgumentError, "Node not found: #{node_name}" if n.nil?
        l.done

        # validate the node is also a host
        raise "Node #{node_name} is hosting its DB into another node." if n[:db].to_s != n[:name].to_s

# TODO: Validate that node has required parameters:
# - ip, postgres_port, postgres_database, postgres_username, postgres_password
#

        # list all files in the folder
        files = []
        n[:migration_folders].each { |migrations_folder|
          l.logs "Listing files in #{migrations_folder.blue}... "
          files += Dir.glob("#{migrations_folder}/*.sql")
          l.done(details: "#{files.size} files found")
        }

        # connect to the database
        # DB ACCESS - KEEP IT SECRET
        # Connection string to the demo database: export DATABASE_URL='postgresql://demo:<ENTER-SQL-USER-PASSWORD>@free-tier14.aws-us-east-1.cockroachlabs.cloud:26257/mysaas?sslmode=verify-full&options=--cluster%3Dmysaas-demo-6448'
        l.logs "Connecting to the database... "
        BlackStack::PostgreSQL::set_db_params({ 
          :db_url => n[:ip],
          :db_port => n[:postgres_port], # default postgres port
          :db_name => n[:postgres_database], 
          :db_user => n[:postgres_username], 
          :db_password => n[:postgres_password],
          :db_sslmode => 'disable',
        })
        @@db = BlackStack::PostgreSQL.connect
        l.done

        # execute the script sentence by sentence
        files.each { |fullfilename|
          l.logs "Running #{fullfilename.blue}... "
          self.execute_sentences( 
            File.open(fullfilename).read,
            logger: nil #l
          )
          l.done
        }

        l.logs "Disconnecting from the database... "
        @@db.disconnect
        l.done
      end # def self.migrations(node_name, logger: nil)
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
      # Setup the DNS, connect the node as `root` and run the `install_ops`.
      def self.install(
        node_name,
        dns_propagation_timeout: 60,
        logger: nil
      )
        l = logger || BlackStack::DummyLogger.new(nil)
        node_name = node_name.dup.to_s

        l.logs "Getting node #{node_name.blue}... "
        node = get_node(node_name)
        raise ArgumentError, "Node not found: #{node_name}" if node.nil?
        l.done
# feature removed
=begin
        # setup domain
        l.logs 'Setting domain or subdomain... '
        if node[:domain]
            nc = BlackOps.namecheap
            domain = node[:domain]
            subdomain = BlackOps.get_subdomain(domain) 
            # DNS records `host`
            host = subdomain || "@" 
            # SLD (secondary level domain)
            sld = subdomain.nil? ? domain : domain.gsub(/#{Regexp.escape(subdomain)}\./, '')
            ip = node[:ip]
            # DNS record `value` 
            value = ip
            nc.add_dns_record(sld, 'A', host, value)
            l.done

            # wait until the ping to a subdomain is pointing to  a specific ip
            l.logs "Check DNS... "
            start_time = Time.now
            end_time = Time.now
            hostname = node[:subdomain] ? "#{node[:subdomain]}.#{node[:domain]}" : node[:domain]
            ip = BlackOps.resolve_ip(hostname, 
              logger: nil
            )
            l.skip(details: 'not propagated yet') if ip.nil?
            l.skip(details: "not propagated yet (wrong IP: #{ip.blue})") if ip && ip != node[:ip]
            l.done if ip && ip == node[:ip]
            while (ip.nil? || ip != node[:ip]) && (end_time - start_time) < dns_propagation_timeout 
                l.logs 'Waiting... '
                sleep(5)
                l.done

                l.logs 'Check DNS... '
                ip = BlackOps.resolve_ip(hostname, 
                  logger: nil
                )
                l.skip(details: 'not propagated yet') if ip.nil?
                l.skip(details: "not propagated yet (wrong IP: #{ip.blue})") if ip && ip != node[:ip]
                l.done if ip && ip == node[:ip]
                end_time = Time.now
            end
            if (ip.nil? || ip != node[:ip])
              raise "DNS propagation not resolved after #{dns_propagation_timeout} seconds."
            end
        else
            l.skip
        end
=end
        # run installation
        node[:install_ops].each { |op|
          l.logs "op: #{op.to_s.blue}... "
          BlackOps.source_remote( node_name,
              op: op,
              connect_as_root: true,
              logger: l
          )
          l.done
        }
      end # def self.install

      # Connect the node as non-root, run the `deploy_ops`, and exeute migrations.
      def self.deploy(
        node_name,
        logger: nil
      )
        l = logger || BlackStack::DummyLogger.new(nil)
        node_name = node_name.dup.to_s

        l.logs "Getting node #{node_name.blue}... "
        node = get_node(node_name)
        raise ArgumentError, "Node not found: #{node_name}" if node.nil?
        l.done

        # run deployment
        node[:deploy_ops].each { |op|
          l.logs "op: #{op.to_s.blue}... "
          BlackOps.source_remote( node_name,
              op: op,
              connect_as_root: false,
              logger: l
          )
          l.done
        }
        
        # run migrations
        l.logs "Running migrations... "
        unless node[:db] && node[:db].to_s == node[:name].to_s
          l.skip(details: "No database hosted by the node.")
        else
          BlackOps.migrations( node_name,
              logger: l
          )
          l.done
        end

      end # def self.deploy
      
      # Connect the node as non-root, run the `start_ops`.
      def self.start(
        node_name,
        logger: nil
      )
        l = logger || BlackStack::DummyLogger.new(nil)
        node_name = node_name.dup.to_s

        l.logs "Getting node #{node_name.blue}... "
        node = get_node(node_name)
        raise ArgumentError, "Node not found: #{node_name}" if node.nil?
        l.done

        # run deployment
        node[:start_ops].each { |op|
          l.logs "op: #{op.to_s.blue}... "
          BlackOps.source_remote( node_name,
              op: op,
              connect_as_root: false,
              logger: l
          )
          l.done
        }        
      end # def self.start

      # Connect the node as non-root, run the `stop_ops`.
      def self.stop(
        node_name,
        logger: nil
      )
        l = logger || BlackStack::DummyLogger.new(nil)
        node_name = node_name.dup.to_s

        l.logs "Getting node #{node_name.blue}... "
        node = get_node(node_name)
        raise ArgumentError, "Node not found: #{node_name}" if node.nil?
        l.done

        # run deployment
        node[:stop_ops].each { |op|
          l.logs "op: #{op.to_s.blue}... "
          BlackOps.source_remote( node_name,
              op: op,
              connect_as_root: false,
              logger: l
          )
          l.done
        }        
      end # def self.stop

    end # BlackOps
#end # BlackStack
    