require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
    BlackOps.source( :slave,
        bash_script_filename: './environment.ubuntu-20-04.pampa',
        params: ['root', 'root-password-here'],
        logger: l
    )
rescue => e
    l.error(e)
end