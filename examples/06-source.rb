require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    BlackOps.source( :master,
        bash_script_filename: 'hostname.op',
        logger: l
    )
rescue => e
    l.error(e)
end