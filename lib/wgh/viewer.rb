require "terminal-table"
require "io/console"
require "colorize"
require "oj"

module Wgh
  class Viewer
    ENTRIES_NAMES = [Cmdb::SERVERS_DB, Cmdb::DEVICES_DB, Cmdb::APPNODES_DB, Cmdb::DEPLOYMENT_DB]
    def initialize(entries = {})
      @entries = entries
      LOG.debug "[viewer] entries: #{entries}"
    end

    def to_s
      "Viewer(#{object_id}) entries count: " +
      ENTRIES_NAMES.map do |entry|
        "#{entry} #{@entries[entry].count rescue '0'}"
      end.join(', ')
    end

    def to_json(*args)
      @entries[Cmdb::SERVERS_DB].map{ |entry| Oj.dump entry.to_h }.join($/)
    end

    def to_table(full = false)
      columns = {}
      columns[Cmdb::SERVERS_DB] = %w[dc host proj role detail o/r st]
      columns[Cmdb::SERVERS_DB] += %w[feip beip] if full
      columns[Cmdb::DEVICES_DB] = %w[dc host device sn loc mgmt]
      columns[Cmdb::APPNODES_DB] = %w[appname realm game proj act maint dns]
      columns[Cmdb::DEPLOYMENT_DB] = %w[host cluster proj role]
      table_entries = {}
      ENTRIES_NAMES.each { |name| table_entries[name] = [] }

      if @entries[Cmdb::SERVERS_DB] && !@entries[Cmdb::SERVERS_DB].empty?
        @entries[Cmdb::SERVERS_DB].each do |server|
          entry = Cmdb::SRV_STD_KEY_SET.map { |key| server[key] }
          entry += Cmdb::IP_STD_KEY_SET.map { |key| server[key] } if full
          entry[5] == entry[6] ? entry.delete_at(6) : entry[5] += '/' + entry.delete_at(6)
          entry[6] = "prod" if entry[6] && entry[6].match(/production/i)
          table_entries[Cmdb::SERVERS_DB] << entry
        end
      end

      if @entries[Cmdb::DEVICES_DB] && !@entries[Cmdb::DEVICES_DB].empty? && full
        @entries[Cmdb::DEVICES_DB].each do |device|
          entry = Cmdb::DEV_STD_KEY_SET.map { |key| device[key] }
          entry[4] = "r#{entry[4]} u#{entry[5]}"
          entry.delete_at 5
          #entry += Cmdb::IP_STD_KEY_SET.map { |key| server[key] }
          table_entries[Cmdb::DEVICES_DB] << entry
        end
      end

      if @entries[Cmdb::APPNODES_DB] && !@entries[Cmdb::APPNODES_DB].empty?
        @entries[Cmdb::APPNODES_DB].each do |app|
          entry = Cmdb::APP_STD_KEY_SET.map { |key| app[key] }
          entry[0] = app["Server"] + ':' + entry[0]
          entry[4] = entry[4].to_s.upcase[0] == 'T' ? 'yes' : 'no'
          table_entries[Cmdb::APPNODES_DB] << entry
        end
      end
      
      if @entries[Cmdb::SERVERS_DB] && !@entries[Cmdb::SERVERS_DB].empty?
        @entries[Cmdb::SERVERS_DB].each do |app|
          next if app["DeploymentCluster"] == nil
          entry = Cmdb::DEPL_STD_KEY_SET.map { |key| app[key] }
          table_entries[Cmdb::DEPLOYMENT_DB] << entry
        end
      end
      

      if @entries[Clusters::CLUSTERS_DB] && !@entries[Clusters::CLUSTERS_DB].empty?
        columns = full ? Clusters::MAX_KEY_SET : Clusters::STD_KEY_SET
        result = @entries[Clusters::CLUSTERS_DB].map { |entry| columns.map { |column| entry[column] }}
        result = result.map { |res| res.map { |s| s.is_a?(String) ? s.slice(0..35) : s } }
        half_table_length = columns.count / 2
        if half_table_length > 4
          result = [columns] + result
          result_splitted = []
          result.each { |x| result_splitted << x[0..half_table_length - 1] << x[half_table_length..-1] << :separator }
          result = result_splitted[0..-2]
        end
        table_output = Terminal::Table.new(:rows => result)
        table_output.headings = columns unless half_table_length > 4
        return table_output.to_s
      end

      tables = []
      ENTRIES_NAMES.each do |name|
        next if table_entries[name].empty?
        table_entries[name] = table_entries[name].map { |entry| entry.map { |s| s.is_a?(String) ? s.slice(0..35) : s }}
        tables << Terminal::Table.new(:rows => table_entries[name], :headings => columns[name]).to_s
      end
      tables.join($/*2)
    end

    def to_jira(full = false)
      to_table(full).split($/).reject{ |x| x =~ /^[+-]+$/ }.join($/)
    end

    def server_names
      return [] if !@entries[Cmdb::SERVERS_DB] || @entries[Cmdb::SERVERS_DB].empty?
      @entries[Cmdb::SERVERS_DB].map { |server| server["Description"] }
    end

    def device_names
      return [] if !@entries[Cmdb::DEVICES_DB] || @entries[Cmdb::DEVICES_DB].empty?
      @entries[Cmdb::DEVICES_DB].map { |device| device["Description"] }
    end

    def datacenters
      return [] if !@entries[Cmdb::SERVERS_DB] || @entries[Cmdb::SERVERS_DB].empty?
      @entries[Cmdb::SERVERS_DB].map { |server| server["Cluster"] }
    end

    def locations
      return [] if !@entries[Cmdb::DEVICES_DB] || @entries[Cmdb::DEVICES_DB].empty?
      @entries[Cmdb::DEVICES_DB].map { |device| %Q(r#{device["rack_name"]} u#{device["PlaceInRack"]}) }
    end

    def serial_numbers
      return [] if !@entries[Cmdb::DEVICES_DB] || @entries[Cmdb::DEVICES_DB].empty?
      @entries[Cmdb::DEVICES_DB].map { |device| device["Serial"] }
    end

    def method_missing(name, *args)
      return @entries[name] if ENTRIES_NAMES.include? name
      super
    end
  end
end
