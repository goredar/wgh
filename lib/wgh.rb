require "wgh/version"
#require "wgh/mysql"
require "wgh/clusters"
require "wgh/cmdb"
require "wgh/mongo"
require "wgh/viewer"
require "goredar/logger"

module Wgh
  DEFAULT_OPTIONS = {
    selectors: {},
    app: nil,
    output: :auto,
    full: false,
    db: :cmdb,
    fuzzy: false,
    config: "~/.config/l1.conf",
    triggers: [],
    records: {},
    self_name: Wgh::NAME,
    }
  class << self

    def update
      #Clusters.update
      Cmdb.update
    rescue Exception => e
      LOG.error { "[app] Failed to update db" }
      LOG.debug { "[app] #{e.message}" }
      LOG.debug { "[app] #{e.backtrace.join($/)}" }
    end

    def find(options = {})
      options = DEFAULT_OPTIONS.merge options
      fuzzy = options[:fuzzy]
      selectors = options[:selectors]
      selectors["hostname"].map! { |hn| hn.split('.').first } if selectors["hostname"].is_a?(Array)
      #records = options[:db] == :cmdb ? Cmdb.find(selectors, fuzzy) : Clusters.find(selectors, fuzzy)
      records = Cmdb.find(selectors, fuzzy)
      # Merge with triggers from options if json output (can pipe back to wgz)
      if options[:triggers] && !options[:triggers].empty? && !$stdout.tty?
        records_triggers = { servers: [] }
        records[:servers].each do |server|
          options[:triggers].each do |trigger|
            records_triggers[:servers] << trigger.merge(server) if trigger["host"].split('.').first == server["Description"]
          end
        end
        records = records_triggers
      end
      LOG.debug "[app] records: #{records}"
      options[:records] = records
      options
    end

    def view(options = {})
      LOG.debug "[view] format: #{options[:output]}, full: #{options[:full]}"
      options = DEFAULT_OPTIONS.merge options
      if options[:output] == :auto
        options[:output] = $stdout.tty? ? :table : :json
      end
      Viewer.new(options[:records]).public_send("to_#{options[:output].to_s}".to_sym, options[:full])
    end
  end
end
