require_relative '../lib/blackops.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('blackops.log')

# Example domains to test
domains = [
  'example.com',
  'sub.example.com',
  'shop.sub.example.com',
  'example.com.ar',
  'shop.example.com.ar',
  'blog.shop.example.com.ar',
  'localhost',
  'invalid_domain',
  'another.invalid_domain.com'
]

l.log "GETTING SUB-DOMAINS:"

domains.each do |domain|
  begin
    l.logs "#{domain.blue}... "
    subdomain = BlackOps.get_subdomain(domain)
    if subdomain
      l.logf subdomain.green
    else
      l.logf 'No subdomain'.yellow
    end
  rescue => e
    l.reset
    l.logf e.message.red
  end
end
