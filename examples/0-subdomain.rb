require_relative '../lib/blackstack-deployment.rb'
require_relative '../config.rb'

l = BlackStack::LocalLogger.new('deploy-examples.log')

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

domains.each do |domain|
  subdomain = BlackStack::Deployment.get_subdomain(domain)
  if subdomain
    puts "Domain: #{domain} => Subdomain: #{subdomain}"
  else
    puts "Domain: #{domain} => No subdomain"
  end
end
