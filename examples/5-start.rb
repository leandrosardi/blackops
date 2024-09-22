require_relative '../lib/blackstack-deployment.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    # start server
    BlackStack::Deployment.source( :worker,
        bash_script_filename: './start.pampa',
        logger: l
    )
rescue => e
    l.error(e)
end