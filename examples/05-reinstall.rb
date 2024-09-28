require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    # start server
    ret = BlackOps.reinstall( :master,
        logger: l
    )

    l.log JSON.pretty_generate(ret) if ret
    l.log "Instance not Found.".yellow if !ret

rescue => e
    l.error(e)
end