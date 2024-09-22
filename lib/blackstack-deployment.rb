require 'pry'
require 'simple_cloud_logging'
require 'simple_command_line_parser'

#require 'blackstack-nodes'
require_relative '/home/leandro/code1/blackstack-nodes/lib/blackstack-nodes.rb'

require 'blackstack-db'

module BlackStack
    module Deployment
      @@nodes = []
      @@db = nil

      CONTABO_PRODUCT_IDS = [
        :V45, 
        :V47, 
        :V46, 
        :V48, 
        :V50, 
        :V49, 
        :V51, 
        :V53, 
        :V52, 
        :V54, 
        :V56, 
        :V55, 
        :V57, 
        :V59, 
        :V58, 
        :V60, 
        :V62, 
        :V61, 
        :V8,  
        :V9,  
        :V10, 
        :V11, 
        :V16
      ]
  
      def self.add_node(h)
        err = []
  
        # Set default values for optional keys if they are missing
        h[:dev] ||= false
        h[:net_remote_ip] ||= nil
        h[:provider] ||= :contabo
        h[:procs] ||= {}
        h[:logs] ||= []
        h[:webs] ||= []
  
        # Validate the presence and format of the mandatory keys
        if h[:name].nil? || !h[:name].is_a?(String) || h[:name].strip.empty?
          err << "Invalid value for :name. Must be a non-empty string."
        end
  
        if ![true, false].include?(h[:dev])
          err << "Invalid value for :dev. Must be a boolean."
        end
  
        if h.key?(:net_remote_ip) && !h[:net_remote_ip].nil?
          unless h[:net_remote_ip] =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
            err << "Invalid value for :net_remote_ip. Must be a valid IP address or nil."
          end
        end
  
        if h[:provider] != :contabo
          err << "Invalid value for :provider. Allowed values: [:contabo]."
        end
  
        if h[:service].nil? || !CONTABO_PRODUCT_IDS.include?(h[:service])
          err << "Invalid value for :service. Allowed values: [#{CONTABO_PRODUCT_IDS.join(', ')}]."
        end
  
        if h[:db_host].nil? || !h[:db_host].is_a?(String) || h[:db_host].strip.empty?
          err << "Invalid value for :db_host. Must be a non-empty string."
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

        # if exists, :procs must by an array of strings
        if h.key?(:procs)
          unless h[:procs].is_a?(Array) && h[:procs].all? { |proc| proc.is_a?(String) }
            err << "Invalid value for :procs. Must be an array of strings."
          end
        end # if h.key?(:procs)

=begin
        if h.key?(:procs)
          unless h[:procs].is_a?(Hash)
            err << "Invalid value for :procs. Must be a hash."
          end
  
          if h[:procs].key?(:start)
            unless h[:procs][:start].is_a?(Array)
              err << "Invalid value for :procs[:start]. Must be an array of commands."
            end
  
            h[:procs][:start].each do |proc|
              unless proc.is_a?(Hash) && proc.key?(:command) && proc[:command].is_a?(String)
                err << "Invalid start process. Each must be a hash with a :command key."
              end
            end
          end

          if h[:procs].key?(:stop)
            unless h[:procs][:stop].is_a?(Array) && h[:procs][:stop].all? { |cmd| cmd.is_a?(String) }
              err << "Invalid value for :procs[:stop]. Must be an array of strings."
            end
          end
        end
=end    
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
  
      # 
      def self.source(
        node_name,
        connect_as_root: false,
        bash_script_filename: nil,
        bash_script_url: nil,
        logger: nil
      )
        node = nil
        begin        
          l = logger || BlackStack::DummyLogger.new(nil)
          node_name = node_name.dup.to_s
          raise ArgumentError, 'Either `bash_script_filename` or `bash_script_url` must be provided.' if bash_script_filename.nil? && bash_script_url.nil?
          raise ArgumentError, 'Only one `bash_script_filename` or `bash_script_url` must be provided.' if bash_script_filename && bash_script_url

          l.logs "Getting node #{node_name.blue}... "
          n0 = get_node(node_name)
          n = n0.clone
          raise ArgumentError, "Node not found: #{node_name}" if n.nil?
          l.done
        
          # download the file from the URL
          if bash_script_url
            l.logs "Downloading bash script from #{bash_script_filename.blue}... "
            bash_script = Net::HTTP.get(URI(bash_script_url)) 
            l.done(details: "#{bash_script.length} bytes downloaded")
          else
            l.logs "Getting bash script from #{bash_script_filename.blue}... "
            bash_script = File.read(bash_script_filename) if bash_script_filename
            l.done(details: "#{bash_script.length} bytes in file")
          end

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
        
          l.logs("Connect to node #{node_name.to_s.blue}... ")
          node.connect
          l.done
          # => n.ssh
        
          # build a list of all the parameters like $foo present into the bash_script varaible
          # scan for variables in the form $VAR
          params = bash_script.scan(/\$([a-zA-Z_][a-zA-Z0-9_]*)/).flatten.uniq

          # verify that there is a key in the hash `n` that matches with each one of the strings present in the array of strings `param`
          missed = params.reject { |key| n.key?(key.to_sym) }
          raise ArgumentError, "Node #{node_name} is missing the following parameters required by the script: #{missed.join(', ')}." if !missed.empty?

          # execute the script fragment by fragment
          bash_script.split(/(?<!#)RUN /).each { |fragment|
            fragment.strip!
            next if fragment.empty?
            next if fragment.start_with?('#')  
            
            l.logs "#{fragment.split(/\n/).first.to_s.strip[0..35].blue.ljust(57, '.')}... "

            # remove all lines starting with `#`
            fragment = fragment.lines.reject { |line| line.strip.start_with?('#') }.join

            # replace params in the fragment. Example: $name is replaced by n[:name]
            params.each { |key|
              fragment.gsub!("$#{key.to_s}", n0[key.to_sym].to_s)
            }
            
            res = node.exec(fragment)
            l.done#(details: res)
          }
        rescue => e
          raise e
        ensure
          l.logs "Disconnect from node #{node_name.blue}... "
          if node && node.ssh
            node.disconnect
            l.done
          else
            l.skip(details: "Node not connected")
          end
        end

      end # def self.source(node_name, logger: nil)
      
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
            s = "ssh -o StrictHostKeyChecking=no -i \"#{Shellwords.escape(node.ssh_private_key_file)}\" #{node.ssh_username}@#{node.net_remote_ip} -p #{node.ssh_port}"
        else
            # DEPRECATED: This is not working, because it is escaping the #
            #escaped_password = Shellwords.escape(node.ssh_private_key_file)
            escaped_password = node.ssh_password.gsub(/\$/, "\\$")
            #s = "sshpass -p \"#{escaped_password}\" ssh -o KbdInteractiveAuthentication=no -o PasswordAuthentication=yes -o PreferredAuthentications=password -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o BatchMode=yes -o UserKnownHostsFile=/dev/null #{node.ssh_username}@#{node.net_remote_ip} -p #{node.ssh_port}"
            s = "sshpass -p \"#{escaped_password}\" ssh -o StrictHostKeyChecking=no #{node.ssh_username}@#{node.net_remote_ip} -p #{node.ssh_port}"
        end

        #t = "ssh-keygen -f \"#{ENV['HOME']}/.ssh/known_hosts2\" -R \"#{n[:net_remote_ip].to_s}\""
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
            l.error(e)
            raise "Error executing statement: #{statement}\n#{e.message}"
          end
        }
      end # def db_execute_sql_sentences_file

      # 
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
        raise "Node #{node_name} is hosting its DB into another node." if n[:db_host].to_s != n[:name].to_s

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
          :db_url => n[:net_remote_ip],
          :db_port => '5432', # default postgres port
          :db_name => 'blackstack', 
          :db_user => 'blackstack', 
          :db_password => n[:ssh_root_password],
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

    end # Deployment
  end # BlackStack
    