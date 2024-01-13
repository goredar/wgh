module Wgh
  class Clusters
    CLUSTERS_DB = :clusters
    STD_KEY_SET = %w[dc hostname project role details owner responsible status]
    MAX_KEY_SET = %w[hostname type dc location sn mgmtip beip feip project role details owner responsible status comments tasks]

    class << self
      def update
        require "spreadsheet"
        name = self.name.split('::').last.downcase
        LOG.info "[#{name}] Starting database update"
        Spreadsheet.client_encoding = 'UTF-8'
        xls_rows = Spreadsheet.open(StringIO.new get_file).worksheet("Data").rows
        raise "[#{name}] Too low number of records" if xls_rows.count < 100
        LOG.info "[#{name}] Spreadsheet has been processed"
        column_names = xls_rows[0].to_a.compact.map{ |name| name.tr(" /_", '') }
        db = Mongo.connect[CLUSTERS_DB]
        db.drop
        db.insert_many xls_rows[1..-1].map { |row| Hash[column_names.zip row ] }
        db.indexes.create_one "hostname" => 1
        LOG.success "[#{name}] Clusters database has been updated"
      end

      def get_file
        require "curb"
        url ||= CONF[:clusters][:url]
        c = Curl::Easy.new url
        c.ssl_verify_peer = false
        c.http_auth_types = :basic
        c.username = CONF[:user]
        c.password = CONF[:pass]
        c.timeout = 13
        c.perform
        LOG.info "[curl] #{url} downloading done"
        c.body_str
      rescue Exception => e
        LOG.error "[curl] Failed to download #{url}: #{e.message}"
        LOG.debug e.backtrace.join($/)
        ""
      end

      def find(selectors = {}, fuzzy = false)
        { CLUSTERS_DB => Mongo.find(CLUSTERS_DB, selectors, fuzzy).to_a }
      end
    end
  end
end
