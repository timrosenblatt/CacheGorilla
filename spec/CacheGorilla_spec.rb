require File.dirname(__FILE__) + '/spec_helper.rb'

# For sneaking a peek during testing
module CacheGorilla
  class CacheGorilla
    # attr_accessor :memcache, :mongo_collection
  
    def mongo_get(key)
      @mongo_collection.find({'_id' => key}).first['data']
    end
  
    def mongo_set(key, value)
      @mongo_collection.update({ '_id' => key }, { '_id' => key, 'data' => value, 'expires' => nil }, { :upsert => true })
    end
  
    def memcache_get(key)
      @memcache.get(key)
    rescue Memcached::NotFound
      nil
    end
  
    def memcache_set(key, value)
      args = [key, value]
      @memcache.set(*args)
    end
  end
end

describe "CacheGorilla" do
  include CacheGorilla
  
  before(:each) do
    @cg = CacheGorilla.new(:db => "cache_gorilla_test")
  end
  
  after(:each) do
    @cg.clear
  end
  
  it "can set and get values" do
    @cg.key?("Unicorns!").should be_false
    
    @cg["Unicorns!"] = "Ponies!"
    
    @cg["Unicorns!"].should == "Ponies!"
  end
  
  it "can check for the presence of a key" do
    @cg.key?("Scrooge").should be_false
    
    @cg["Scrooge"] = "Christmas Spirit"
    
    @cg.key?("Scrooge").should be_true
  end
  
  it "can delete keys" do
    @cg["Unicorns!"] = "Ponies!"
    @cg.delete("Unicorns!")
    
    @cg.key?("Unicorns!").should be_false
  end
  
  it "respects expirations" do
    @cg.store("key", "value", { :expires_in => 5 })
    sleep(6)
    @cg["key"].should be_nil
  end
  
  it "fills memcache on cache misses" do
    @cg.memcache_get("key").should be_nil
    @cg.mongo_set("key", "value")
    
    @cg["key"].should == "value"
    
    @cg.memcache_get("key").should == "value"
  end
  
  it "returns nil when a key is not found" do
    @cg["EasterBunny"].should be_nil
  end
  
  it "sets values in both memcache and mongo" do
    @cg["key"] = "value"
    
    @cg.mongo_get("key").should == "value"
    @cg.memcache_get("key").should == "value"
  end
  
end
