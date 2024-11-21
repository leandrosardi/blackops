require_relative '../lib/blackops.rb'

l = BlackStack::LocalLogger.new('blackops.log')

begin
  # migrations
  BlackOps.standard_migrations_processing(
    arguments: ARGV,
    logger: l  
  )
rescue => e
  l.reset
  l.log(e.to_console.red)
end
