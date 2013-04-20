require "bundler/setup"
require "sinatra"
require "service"

FileUtils.mkdir_p 'log' unless File.exists?('log')
log = File.new("log/sinatra.log", "a+")
STDOUT.reopen(log)
STDERR.reopen(log)

log2 = File.new("log/branch.log", "a+")
STDOUT.reopen(log2)
STDERR.reopen(log2)

run Service