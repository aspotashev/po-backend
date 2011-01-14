#!/usr/bin/ruby
# encoding: utf-8

require 'drb'
require 'active_support' # from Ruby on Rails
require 'yaml'

$conf = YAML::load(File.open(ARGV[0] || File.join(File.dirname(__FILE__), 'config.yml')))

REPO_ROOT=$conf['ru_trunk']


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

#trap("INT") { DRb.stop_service }

DRb.thread.join

