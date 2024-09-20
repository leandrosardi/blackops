require_relative '../lib/blackstack-deployment.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    BlackStack::Deployment.deploy( :slave,
        bash_script_filename: './master.blackstack',
        logger: l
    )
rescue => e
    l.error(e)
end