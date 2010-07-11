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
    # :server sets up memcache, :host sets up mongo
    def initialize(options = {})
      @options = {
        :host => ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost',
        :port => ENV['MONGO_RUBY_DRIVER_PORT'] || 27017,
        :db => 'cache',
        :collection => 'cache',
        :server => 'localhost'
      }.update(options)

      @mongo_connection = Mongo::Connection.new(@options[:host], @options[:port], :pool_size => 5, :timeout => 5)
      @mongo_collection = @mongo_connection.db(@options[:db]).collection(@options[:collection])
      
      @memcache = MemCache.new(options[:server], @options)
    end

    def key?(key)
      !!self[key]
    end
    
    alias has_key? key?

    def [](key)      
      begin
        @memcache.get(key)
      rescue Memcached::NotFound
        res = @mongo_collection.find({'_id' => key}).first
        res = nil if res && res['expires'] && Time.now > res['expires']
        
        if res
          args = [res['_id'], res['data'], res['expires']].compact
          @memcache.set(*args)
        end
        
        res && res['data']
      end
    end

    def []=(key, value)
      store(key, value)
    end

    def delete(key)
      # todo What's the best way to run these two calls at once, given that it's very much one-at-a-time
      value = self[key]
      @mongo_collection.remove('_id' => key) if value
      @memcache.delete(key) if value
      value
    end
    
    # Pass an option of :bypass_memcache if you want. Set the key to any value.
    def store(key, value, options = {})
      # todo What's the best way to run these two calls at once, given that it's very much one-at-a-time
      exp = options[:expires_in] ? (Time.now + options[:expires_in]) : nil
      @mongo_collection.update({ '_id' => key }, { '_id' => key, 'data' => value, 'expires' => exp }, { :upsert => true }) # upsert is the best technical term ever.
      
      unless options.has_key?(:bypass_memcache)
        args = [key, value, options[:expires_in]].compact
        @memcache.set(*args)
      end
      
      value
    end

    def clear
      @mongo_connection.drop_database(@options[:db])
      @memcache.flush
    end
  end
end