require_relative '../lib/blackops.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
  # arguments
  BlackOps.standard_operation_bundle(
    arguments: ARGV,
    operation_bundle_name: 'stop',
    logger: l  
  )
rescue => e
  l.reset
  l.log(e.to_console.red)
end
