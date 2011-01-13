#!/usr/bin/ruby
# encoding: utf-8

require 'drb'
require 'active_support' # from Ruby on Rails
require 'yaml'
require 'logger'

$conf = YAML::load(File.open(ARGV[0] || 'config.yml'))

REPO_ROOT=$conf['ru_trunk']

# http://stackoverflow.com/questions/224512/redirect-the-puts-command-output-to-a-log-file
# http://www.ruby-doc.org/core/classes/Logger.html
$log = Logger.new("/tmp/po-backend.log")
$log.level = Logger::DEBUG

$stdout.reopen("/tmp/po-backend.log.stdout", 'w')
$stdout.sync = true
$stderr.reopen("/tmp/po-backend.log.stderr", 'w')
$stderr.sync = true


class TeamStats
	include DRbUndumped

	def list_files_gui
		@cache ||= list_all_files.select {|x| x.match(/^messages\/[a-zA-Z\-\_0-9]+\/[a-zA-Z\-\_0-9]+\.po$/) }
	end

private
	def list_all_files
		`cd #{REPO_ROOT} ; git-ls-tree HEAD -r --name-only`.split("\n")
	end
end

def get_tempfile
	'/tmp/po-backend-' + Time.now.to_i.to_s + rand.to_s
#	`tempfile`.strip
end

class ISearch
	include DRbUndumped

	def initialize
		@conf = $conf['isearch']

		require @conf['binary_ruby_module']
		IndexSearch.init(@conf['dump'], @conf['dump_index'], @conf['dump_map'])
	end

	def find(s, n)
		IndexSearch.find(s, n)
	end
end

class PoBackend
	attr_accessor :team_stats
	attr_accessor :isearch

	def initialize
		@team_stats = TeamStats.new
		@isearch = ISearch.new
	end
end

`rm -f /tmp/po-backend-unix-socket`
DRb.start_service 'drbunix:///tmp/po-backend-unix-socket', PoBackend.new
$log.info "Server running at #{DRb.uri}"

#trap("INT") { DRb.stop_service }

DRb.thread.join

