module Wgh
  module Mysql

    def connect_to_db
      require "mysql2"
      @db ||= Mysql2::Client.new(
        host: CONF[:host] || 'localhost',
        username: CONF[:sql_user] || 'wg_user',
        password: CONF[:sql_pass] || 'wg_pass',
        database: CONF[:database] || 'wg_clusters',
        )
    end

    def drop_table(table = nil)
      connect_to_db
      @db.query %Q(DROP TABLE IF EXISTS #{table || CONF[:table]})
    end

    def rename_table(table, new_name)
      connect_to_db
      @db.query %Q(RENAME TABLE #{table} TO #{new_name})
    end

    def create_table(columns, limit = 19, table = nil)
      connect_to_db
      table ||= CONF[:table]
      columns_str = columns[0..limit].map { |c| %Q[#{c.tr(%q["\/ '], '')} VARCHAR(128)] }.join(", ")
      @db.query %Q[CREATE TABLE IF NOT EXISTS #{table} (#{columns_str})]
    end

    def insert_into_table(rows, limit = 19, table = nil)
      connect_to_db
      table ||= CONF[:table]
      rows.map do |row|
        %Q[(#{row.fill('', row.length..limit)[0..limit].map { |v| "\"#{@db.escape v.to_s}\"" }.join ','})]
      end.each_slice(1000) do |s|
        @db.query %Q[INSERT INTO #{table} VALUES #{s.join ','}]
      end
    end

    def select_from_table(selectors, columns = [], table = nil)
      connect_to_db
      table ||= CONF[:table] || 'layout'
      sel_str = selectors.map do |name, pattern|
        if pattern.respond_to? :each
          %Q[(#{pattern.map { |pat| %Q[#{name} LIKE '%#{pat}%'] }.join(' OR ')})]
        else
          %Q[#{name} LIKE '%#{pattern}%']
        end
      end.join(' AND ')
      query_str = %Q[SELECT #{columns.empty? ? '*' : columns.join(',')} FROM #{table}]
      query_str += %Q[ WHERE #{sel_str}] unless sel_str.empty?
      @db.query query_str
    end
    alias find select_from_table

    def backup_table(table = nil)
      table ||= CONF[:table]
      drop_table "#{table}_backup"
      rename_table table, "#{table}_backup"
      LOG.success "Table '#{table}' has been backed up."
    rescue Exception => e
      LOG.error "Failed to backup '#{table}': #{e.message}"
      LOG.debug e.backtrace.join($/)
    end

    def restore_table(table = nil)
      table ||= CONF[:table]
      drop_table table
      rename_table "#{table}_backup", table
      LOG.success "Table '#{table}' has been restored."
    rescue Exception => e
      LOG.error "Failed to restore '#{table}': #{e.message}"
      LOG.debug e.backtrace.join($/)
    end
  end
end
