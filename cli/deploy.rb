require_relative '../lib/blackops.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
  # operations
  BlackOps.standard_operation_bundle(
    arguments: ARGV,
    operation_bundle_name: 'deploy',
    logger: l  
  )
rescue => e
  l.reset
  l.log(e.to_console.red)
end
