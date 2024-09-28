require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

begin
    BlackOps.ssh( :master,
        connect_as_root: true,
        logger: l
    )
rescue => e
    l.error(e)
end