#!/usr/bin/ruby

require 'drb'

REPO_ROOT='~/kde-ru/kde-ru-trunk.git'

class TeamStats
	def list_files_gui
		@cache ||= list_all_files.select {|x| x.match(/^messages\/[a-zA-Z\-\_0-9]+\/[a-zA-Z\-\_0-9]+\.po$/) }
	end

private
	def list_all_files
		`cd #{REPO_ROOT} ; git-ls-tree HEAD -r --name-only`.split("\n")
	end
end

DRb.start_service 'druby://:9000', TeamStats.new
puts "Server running at #{DRb.uri}"

trap("INT") { DRb.stop_service }
DRb.thread.join

