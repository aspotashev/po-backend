#!/usr/bin/ruby
# encoding: utf-8

require 'drb'
require 'xml' # gem install libxml-ruby
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

class Gettext
	include DRbUndumped

	def check_po_validity(content)
		tempfile = get_tempfile
		tempfile_po = tempfile + '.po'

		File.open(tempfile_po, 'w') {|f| f.print content }
		`msgfmt --check #{tempfile_po} -o - 2> #{tempfile} > /dev/null`

		res = File.read(tempfile)

		`rm -f #{tempfile}`
		`rm -f #{tempfile_po}`

		res.empty? ? nil : res # 'nil' = no errors
	end
end

class PoSieve
	include DRbUndumped

	extend ActiveSupport::Memoizable

	def recalc_offset(offset, msgstr)
		res = []
		s = nil
		index = 0

		allowed_chars = /[^a-zA-Z&áňŠěéČć³²]/u # see pology/lang/ru/rules/check-spell.rules
		while (s = msgstr[index..-1]).index(allowed_chars)
			index += s.index(allowed_chars)
			res << index
			index += 1
		end

		res[offset] || offset
	end

	def check_rules(content)
		$log.info "check_rules: begin"

		tempfile = get_tempfile
		File.open(tempfile + '.po', 'w') {|f| f.write(content) }
		`#{$conf['pology_path']}/scripts/posieve.py check-rules --skip-obsolete -slang:ru -snomsg #{tempfile + '.po'} -sxml:#{tempfile + '.xml'}`
		xml = File.open(tempfile + '.xml').read

		`rm -f #{tempfile + '.xml'}`
		`rm -f #{tempfile + '.po'}`

		parser = XML::Parser.string(xml)
		doc = parser.parse


		res = doc.find('//error').map do |err|
			h = {}

			err.find('*').each do |arg|
				if arg.name == 'highlight'
					msgstr = err.find('msgstr')[0].content
					msgstr_begin = recalc_offset(arg.attributes[:begin].to_i, msgstr)
					msgstr_end = recalc_offset(arg.attributes[:end].to_i, msgstr)

					h = h.merge({ :highlight => (msgstr_begin...msgstr_end) })
				else
					h = h.merge({ arg.name.to_sym => arg.content })
				end
			end

			h
		end

		$log.info "check_rules: end"
		res
	end

	memoize :check_rules # we can remove this, because the Rails application should can results itself (e.g., in a database)
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
	attr_accessor :posieve
	attr_accessor :gettext
	attr_accessor :isearch

	def initialize
		@team_stats = TeamStats.new
		@posieve = PoSieve.new
		@gettext = Gettext.new
		@isearch = ISearch.new
	end
end

`rm -f /tmp/po-backend-unix-socket`
DRb.start_service 'drbunix:///tmp/po-backend-unix-socket', PoBackend.new
$log.info "Server running at #{DRb.uri}"

#trap("INT") { DRb.stop_service }

DRb.thread.join

