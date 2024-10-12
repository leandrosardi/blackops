require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

# Check if a script name is provided
if ARGV[0] == '--help' || ARGV[0] == '--h' || ARGV[0] == '-h'
    puts "This command merges the list of nodes in the configuration file with the nodes configured in Contabo, and show a list of nodes with infrastructure information."
    puts "Usage: ops ssh <optional: pattern filter nodes>"
    exit 1
end
  
x = ARGV.shift # Get pattern

begin
    l.logs "Pattern: " 
    if x
        l.logf x.blue
    else
        l.logf '(all)'.blue
    end

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
    # :tag=>"demo",
    # :provider=>:contabo,
    # :service=>:V45,
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

    # Create a hash with IP as the key for easy lookup from nodes and instances
    # - Merge the arrays `instances` and `nodes` into one single array `all`.
    # - The key to merge both arrays is the IPv4 on each element.
    # - Each element into the `all` array must have the following keys:
    #   - ip defined in either `nodes` or `instances`
    #   - node name defined in `nodes`
    #   - instance name defined in `instances`
    #   - cancelData defined in `instances`
    all = nodes.map { |node| { :node => node } }
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

    # Define the table rows
    rows = []
    rows << [
        'Name'.bold, 
        'IP'.bold, 
        'Contabo'.bold, 
        'Expire'.bold,
    ]
    
    all.each { |j|
        ip = j[:node][:ip] if j[:node]
        ip = j[:instance].dig('ipConfig', 'v4', 'ip') if ip.nil? && j[:instance]

        rows << [
            j[:node].nil? ? '-' : j[:node][:name], 
            ip, 
            j[:instance].nil? ? '-' : j[:instance]['name'], 
            j[:instance].nil? ? '-' : j[:instance]['cancelDate']
        ]
    }

    # Create the table with a title
    table = Terminal::Table.new :title => "Nodes List", :rows => rows do |t|
        t.style = {
            border_x: '',  # Horizontal border character
            border_y: '',  # Vertical border character
            border_i: ''   # Intersection character
        }
    end
    
    # Display the table in the terminal
    puts table
    
rescue => e
    l.reset
    l.log(e.to_console.red)
end