require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    l.logs('Get node master... ')
    n = BlackOps.get_node('master')
    l.done

    # switch user to root and create the node object
    l.logs "Creating node object... "
    new_ssh_username = n[:ssh_username]
    new_hostname = n[:name]
    n[:ssh_username] = 'root'
    n[:ssh_password] = n[:ssh_root_password]
    node = BlackStack::Infrastructure::Node.new(n)
    l.done

    l.logs('Connect to node master... ')
    node.connect
    l.done
    # => n.ssh

    l.logs 'Valid command: `hostname`... ' 
    l.logf node.exec('hostname').blue
    # => 'dev1'

    l.logs 'Invalid command: `rm`... ' 
    l.logf node.exec('rm').blue
    # => 'dev1'

    l.logs 'Disconnect from node master... '
    n.disconnect
    l.done
    # => nil

rescue => e
    l.error(e)
end