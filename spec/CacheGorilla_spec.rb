require File.dirname(__FILE__) + '/spec_helper.rb'

describe "CacheGorilla" do
  include CacheGorilla
  
  before(:each) do
    @cg = CacheGorilla.new(:db => "cache_gorilla_test")
  end
  
  after(:each) do
    @cg.drop_database("cache_gorilla_test")
  end
  
  it "can set and get values" do
    @cg.key?("Unicorns!").should be_false
    @cg["Unicorns!"] = "Ponies!"
    @cg["Unicorns!"].should == "Ponies!"
  end
  
  it "can check for the presence of a key" do
    @cg.key?("Unicorns!").should be_false
    @cg["Unicorns!"] = "Ponies!"
    @cg.key?("Unicorns!").should be_true
  end
  
  it "can delete keys" do
    @cg["Unicorns!"] = "Ponies!"
    @cg.delete("Unicorns!")
    @cg.key?("Unicorns!").should be_false
  end
  
end
