require_relative '../lib/blackstack-deployment.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    # setup domain
    l.logs 'Setting domain... '
    node = BlackStack::Deployment.get_node(:slave)
    if node && node[:domain]
        nc = BlackStack::Deployment.namecheap
        domain = node[:domain]
        subdomain = node[:subdomain].nil? ? domain : "#{node[:subdomain]}.#{node[:domain]}"
        ip = node[:net_remote_ip]
#binding.pry
        nc.add_dns_record(domain, 'A', subdomain, ip)
        l.done
    else
        l.skip
    end


    # run installation
    BlackStack::Deployment.source( :slave,
        bash_script_filename: './install.pampa',
        connect_as_root: true,
        logger: l
    )
    
rescue => e
    l.error(e)
end