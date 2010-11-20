#!/usr/bin/ruby

require 'drb'

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

class PoBackend
	attr_accessor :team_stats

	def initialize
		@team_stats = TeamStats.new
	end
end

DRb.start_service 'druby://:9000', PoBackend.new
puts "Server running at #{DRb.uri}"

trap("INT") { DRb.stop_service }
DRb.thread.join

