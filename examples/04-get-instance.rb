require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    # start server
    BlackOps.get_instance( :master,
        logger: l
    )
rescue => e
    l.error(e)
end