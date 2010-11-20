#!/usr/bin/ruby

require 'drb'

server = DRbObject.new nil, 'druby://:9000'

p server.team_stats.list_files_gui

p server.posieve.check_rules(File.new('/home/sasha/messages/extragear-base/desktop_extragear-base_networkmanagement.po').read)
