#!/usr/bin/ruby

require 'drb'

server = DRbObject.new nil, 'druby://:9000'

10000.times do
	server.list_files_gui
	print '*'
	STDOUT.flush
end

puts

