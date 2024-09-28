require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    # start server
    BlackStack::Deployment.source( :master,
        bash_script_filename: './stop.pampa',
        logger: l
    )
rescue => e
    l.error(e)
end