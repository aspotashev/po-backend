#!/usr/bin/ruby

require 'drb'
require 'xml' # gem install libxml-ruby
require 'active_support'

REPO_ROOT='~/kde-ru/kde-ru-trunk.git'

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

class PoSieve
	include DRbUndumped

	extend ActiveSupport::Memoizable

	def check_rules(content)
		tempfile = `tempfile`.strip
		File.open(tempfile + '.po', 'w') {|f| f.write(content) }
		`/home/sasha/pology/scripts/posieve.py check-rules -slang:ru -snomsg #{tempfile + '.po'} -sxml:#{tempfile + '.xml'}`
		xml = File.open(tempfile + '.xml').read


		parser = XML::Parser.new
		parser.string = xml
		doc = parser.parse


		doc.find('//error').map do |err|
			h = {}

			err.find('*').each do |arg|
				h = h.merge({ arg.name.to_sym => arg.content })
			end

			h
		end
	end

	memoize :check_rules
end

class PoBackend
	attr_accessor :team_stats
	attr_accessor :posieve

	def initialize
		@team_stats = TeamStats.new
		@posieve = PoSieve.new
	end
end

DRb.start_service 'druby://:9000', PoBackend.new
puts "Server running at #{DRb.uri}"

trap("INT") { DRb.stop_service }
DRb.thread.join

