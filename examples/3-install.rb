require_relative '../lib/blackstack-deployment.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    # TODO: Setup GoDaddy sub-domain
    # CANCELED: Manage list of domains (instead of only one) --> Lets's manage 1 domain per subaccount.

    BlackStack::Deployment.source( :worker,
        bash_script_filename: './install.pampa',
        connect_as_root: true,
        logger: l
    )
    
rescue => e
    l.error(e)
end