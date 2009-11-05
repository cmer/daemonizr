require 'rubygems'  
require 'rake'  
require 'echoe'  
  
Echoe.new('daemonizr') do |p|  
  p.description     = "Process forking and monitoring for mere mortals"
  p.url             = "http://github.com/cmer/daemonizr"  
  p.author          = "Carl Mercier"  
  p.email           = "carl@carlmercier.com"  
  p.ignore_pattern  = ["tmp/*", "script/*", "pkg/*"]  
  p.development_dependencies = []  
end  
  
Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }