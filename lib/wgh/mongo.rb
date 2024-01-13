module Wgh
  module Mongo
    class << self
      def connect(db = nil)
        require 'mongo'
        unless @db
          ::Mongo::Logger.logger = LOG
          @db = ::Mongo::Client.new((CONF[:wgh][:mongo][:host] rescue ['localhost']),
                                    :database => (db || (CONF[:wgh][:mongo][:db] rescue 'host_info')),
                                    #:user => CONF[:wgh][:mongo][:user],
                                    #:password => CONF[:wgh][:mongo][:pass],
                                    #:connection_timeout => 1,
                                    :server_selection_timeout => 1,
                                   )
        end
        @db
      end

      def find(db = nil, selectors = {}, fuzzy = false)
        return [] if (selectors.empty? || db.nil?)
        db = self.connect[db]
        if fuzzy
          selectors = selectors.map do |name, sel|
            sel = sel.map { |val| val.is_a?(String) ? Regexp.new(val, Regexp::IGNORECASE) : val } if sel.respond_to?(:each)
            sel = sel.is_a?(String) ? Regexp.new(sel, Regexp::IGNORECASE) : sel
            [name, sel]
          end
          selectors = Hash[selectors]
        end
        LOG.debug "[mongo] ns: #{db.name}, request: #{selectors}"
        query = selectors.reduce({}) { |q, sel| q[sel[0]] = sel[1].respond_to?(:each) ? { "$in" => sel[1] } : sel[1]; q }
        db.find query
      end
    end
  end
end
