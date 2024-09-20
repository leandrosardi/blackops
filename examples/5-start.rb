require_relative '../lib/blackstack-deployment.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    # run migrations
    BlackStack::Deployment.start( :master,
        logger: l
    )
rescue => e
    l.error(e)
end