module Wgh
  module Cmdb
    BASE_API_URL = "/services/rest/v1/"
    SERVERS_DB = :servers
    DEVICES_DB = :devices
    APPNODES_DB = :appnodes
    DEPLOYMENT_DB = :deployment
    SRV_STD_KEY_SET = %w[Cluster Description Project Role Details Owner Responsible State]
    APP_STD_KEY_SET = %w[Description Realm Game Project Active Maintainer DNS]
    DEV_STD_KEY_SET = %w[DC Server Description Serial rack_name PlaceInRack mgmtip]
    IP_STD_KEY_SET = %w[FeIP BeIP]
    DEPL_STD_KEY_SET = %w[Description DeploymentCluster DeploymentProject DeploymentRole]

    class << self
      def authenticate
        require 'oj'
        require 'curb'
        return(true) if @auth_id
        @curl = Curl::Easy.new(CONF[:cmdb][:url].chomp('/') + BASE_API_URL + "sessions/")
        @curl.ssl_verify_peer = false
        @curl.headers['Accept'] = 'application/json'
        @curl.headers['Content-Type'] = 'application/json'
        @curl.connect_timeout = (CONF[:wgh][:curl][:connect_timeout] rescue 5)
        @curl.timeout = (CONF[:wgh][:curl][:timeout] rescue 90)
        request = { 'username' => "#{CONF[:user]}@wargaming.net", 'password' => CONF[:pass], 'role' => (CONF[:cmdb][:role] || "L1") }
        @curl.post Oj.dump request
        responce = Oj.load(@curl.body_str) rescue (LOG.error("[jrpc] Invalid responce: #{@curl.body_str.split.join}"); return false)
        @auth_id = responce["data"]["_id"]
        @curl.headers['CMDBuild-Authorization'] = @auth_id
      rescue Exception => e
        LOG.error { "[cmdb] Authentication's failed: #{e.message}" }
        LOG.debug { "[cmdb] #{e.backtrace.join($/)}" }
        return nil
      end

      def request(url)
        if authenticate
          @curl.url = CONF[:cmdb][:url].chomp('/') + BASE_API_URL + url
          @curl.get
          Oj.load(@curl.body_str).fetch("data")
        else
          nil
        end
      rescue Exception => e
        LOG.error "[cmdb] Request to #{url} has failed: #{e.message}"
        LOG.debug e.backtrace.join($/)
        return nil
      end

      def get_classes
        request("classes").map { |klass| klass["_id"] }
      end

      def get_class(class_name)
        request "classes/#{build_class_name class_name}"
      end

      def get_all_cards(class_name)
        request "classes/#{build_class_name class_name}/cards/"
      end

      def get_card(class_name, card_id)
        request "classes/#{build_class_name class_name}/cards/#{card_id}"
      end

      def lookup_types
        request "lookup_types/"
      end

      def get_lookup_values(lookup)
        request "lookup_types/#{lookup}/values/"
      end

      def get_servers
        get_class_entries(:server).map do |card|
          Hash[
            card.map do |key, value|
              key = CMDB_SERVER_COLUMN_NAME_MAP[key]
              key ? [key, value] : nil
            end.compact
          ]
        end
      end

      def get_and_simple_embed(class_name, reference_names = {}, lookups = {})
        reference_names = Hash[reference_names.map { |name| [name, name] }] if reference_names.is_a? Array
        reference = reference_names.inject({}) { |ref, name| ref[name[0]] = {}; ref }
        reference.merge! lookups.inject({}) { |ref, name| ref[name[0]] = {}; ref }
        reference_names.each { |db_name, key_name| get_all_cards(db_name).each { |item| reference[db_name][item["_id"]] = item["Code"] } }
        lookups.each { |name, key_name| get_lookup_values(name).each { |item| reference[name][item["_id"]] = item["code"] } }
        reference_names.merge! lookups
        cards = get_all_cards class_name
        cards.each { |card| reference_names.each { |db_name, key_name| card[key_name] = reference[db_name][card[key_name]] } }
      end

      def update
        LOG.info "[cmdb] Starting AppNode database update"
        db = Mongo.connect
        apps = get_and_simple_embed :application, %w[Game Realm], { "ApplicationMaintainer" => "Maintainer" }
        apps = Hash[apps.map { |app| [app["_id"], app] }]
        app_nodes = Cmdb.get_all_cards "AppNode"
        app_nodes.each { |node| node["Application"] = apps[node["Application"]] }
        db[APPNODES_DB].drop
        db[APPNODES_DB].insert_many app_nodes
        db[APPNODES_DB].indexes.create_one "Server" => 1
        LOG.success "[cmdb] AppNode database has been updated"
        LOG.info "[cmdb] Starting Servers database update"
        #servers = get_all_cards :server
        servers = get_and_simple_embed :server, {"DeploymentClustersList" => "DeploymentCluster", "DeploymentRolesList" => "DeploymentRole", "DeploymentProjectList" => "DeploymentProject"}
        db[SERVERS_DB].drop
        db[SERVERS_DB].insert_many servers
        db[SERVERS_DB].indexes.create_one "Description" => 1
        LOG.success "[cmdb] Servers database has been updated"
        LOG.info "[cmdb] Starting Devices database update"
        devices = get_and_simple_embed :device, {"DataCenter" => "DC"}
        db[DEVICES_DB].drop
        db[DEVICES_DB].insert_many devices
        db[DEVICES_DB].indexes.create_one "Serial" => 1
        db[DEVICES_DB].indexes.create_one "Description"=> 1
        LOG.success "[cmdb] Devices databse has been updated"
      end

      def find(selectors = {}, fuzzy = false)
        result = {}
        # Prepare app, dns selectors and ...
        app_selectors = selectors.delete(:app) || ''
        dns_names = selectors.delete(:dns) || ''
        app_name, realm, game = app_selectors.split(':')
        dns_names = dns_names.split(',')
        app_query = {}
        app_query["Application.Description"] = app_name if app_name && !app_name.empty?
        app_query["Application.Realm"] = realm if realm && !realm.empty?
        app_query["Application.Game"] = [game, nil] if game && !game.empty?
        app_query["Application.DNS"] = dns_names if dns_names && !dns_names.empty?
        # ... server selectors
        selectors = Hash[selectors.map { |k, v| [SRV_STD_KEY_SET[Wgh::Clusters::STD_KEY_SET.index(k)], v] }]

        if !selectors.empty?
          # Find servers
          result[SERVERS_DB] = Mongo.find(SERVERS_DB, selectors, fuzzy).to_a
          # Found no servers: try to find devices
          if selectors["Description"] && result[SERVERS_DB].empty?
            result[DEVICES_DB] = Mongo.find(DEVICES_DB, { "Description" => selectors["Description"] }, fuzzy).to_a
          end
          
          # Find linked apps
          result[APPNODES_DB] ||= []
          if app_query.empty?
            result[SERVERS_DB].each do |server|
              result[APPNODES_DB] += Mongo.find(APPNODES_DB, {"Server" => server["_id"]}).to_a.map do |app_node|
                app_node["Application"].merge "Active" => app_node["Active"], "Server" => server["Description"]
              end
            end
          else
            result[SERVERS_DB].select! do |server|
              query = {"Server" => server["_id"]}.merge app_query
              app = Mongo.find(APPNODES_DB, query, fuzzy).to_a.map do |app_node|
                app_node["Application"].merge "Active" => app_node["Active"], "Server" => server["Description"]
              end
              result[APPNODES_DB] += app
              !app.empty?
            end
          end
        else
          # Find appnodes
          result[APPNODES_DB] = Mongo.find(APPNODES_DB, app_query, fuzzy).to_a
          # Add servers from appnodes
          result[APPNODES_DB].map! do |app_node|
            server = Mongo.find(SERVERS_DB, { "_id" => app_node["Server"] }).to_a.first
            result[SERVERS_DB] ||= []
            result[SERVERS_DB] += [server] if server
            server_name = server ? server["Description"] : 'unknown'
            app_node["Application"].merge "Active" => app_node["Active"], "Server" => server_name
          end
        end
        # Find device by server
        result[DEVICES_DB] ||= []
        result[SERVERS_DB] ||= []
        result[SERVERS_DB].each do |server|
          next if server["Type"] == "virtual"
          dev_selector = server["DeviceCode"] ? { "_id" => server["DeviceCode"] } : { "Serial" => server["SerialNumber"] }
          next if dev_selector == { "Serial" => nil }
          result[DEVICES_DB] += Mongo.find(DEVICES_DB, dev_selector, true).to_a.map do |device|
            device["Server"] = server["Description"]
            device
          end
        end
        result
      end

      private

      def build_class_name(class_name)
        class_name.is_a?(String) ? class_name : class_name.to_s.capitalize
      end
    end
  end
end
