require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    # setup domain
    l.logs 'Setting domain or subdomain... '
    node = BlackOps.get_node(:slave)
    if node && node[:domain]
        nc = BlackOps.namecheap
        domain = node[:domain]
        subdomain = BlackOps.get_subdomain(domain) || "@"
        ip = node[:ip]
        nc.add_dns_record(domain, 'A', subdomain, ip)
        l.done

        # wait until the ping to a subdomain is pointing to  a specific ip
        hostname = node[:subdomain] ? "#{node[:subdomain]}.#{node[:domain]}" : node[:domain]
        while BlackOps.resolve_ip(hostname, logger: l).nil?
            l.logs 'Delay... '
            sleep(5)
            l.done
        end
    else
        l.skip
    end

    # wait until 

    # run installation
    BlackOps.source( :slave,
        bash_script_filename: './install.pampa',
        connect_as_root: true,
        logger: l
    )
    
rescue => e
    l.reset
    l.error(e)
end