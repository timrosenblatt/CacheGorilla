$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module CacheGorilla
  VERSION = '0.0.1'
  
  begin
    require "memcached"
    MemCache = Memcached
  rescue LoadError
    begin
      require "memcache"
    rescue LoadError
      puts "You need either the `memcached` or `memcache-client` gem"
      exit
    end
  rescue
    puts "You need either the `memcached` or `memcache-client` gem"
    exit
  end

  begin
    require "mongo"
  rescue LoadError
    puts "You need the mongo gem"
    exit
  end

  # This code is heavily inspired by Yehuda's Moneta (http://github.com/wycats/moneta)
  class CacheGorilla
    def initialize(options = {})
      options = {
        :host => ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost',
        :port => ENV['MONGO_RUBY_DRIVER_PORT'] || 27017,
        :db => 'cache',
        :collection => 'cache'
      }.update(options)

      @mongo_connection = Mongo::Connection.new("localhost", 27017, :pool_size => 5, :timeout => 5)

      @mongo_collection = @mongo_connection.db(options[:db]).collection(options[:collection])
    end

    def key?(key)
      !!self[key]
    end

    def [](key)
      res = @mongo_collection.find({'_id' => key}).first
      res = nil if res && res['expires'] && Time.now > res['expires']
      res && res['data']
    end

    def []=(key, value)
      store(key, value)
    end

    def delete(key)
      value = self[key]
      @mongo_collection.remove('_id' => key) if value
      value
    end

    def store(key, value, options = {})
      exp = options[:expires_in] ? (Time.now + options[:expires_in]) : nil
      @mongo_collection.update({ '_id' => key }, { '_id' => key, 'data' => value, 'expires' => exp }, { :upsert => true }) # upsert is the best technical term ever.
    end

    # Not sure this is useful anymore, since :upsert is being used in #store
    def update_key(key, options = {})
      val = self[key]
      self.store(key, val, options)
    end

    def clear
      @mongo_collection.clear
    end
    
    def drop_database(name)
      @mongo_connection.drop_database(name)
    end
  end
end