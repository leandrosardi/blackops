require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    # start server
    BlackOps.source( :master,
        bash_script_filename: './stop.pampa',
        logger: l
    )
rescue => e
    l.log(e.to_console.red)
end