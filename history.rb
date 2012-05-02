require 'rubygems'
require 'restclient'
require 'json'
require 'sequel'
require 'set'
require 'time-lord'

DB = Sequel::Database.connect(ENV["DATABASE_URL"] || 'sqlite://db.db')

class Stats
  def initialize(filter = 300)
    @all = DB[:pages].all.each do |i|
      i[:date]      = i[:created_on].to_date
      i[:date_time] = i[:created_on].to_datetime
    end
    kill = Set.new
    (0..@all.size-2).each {|i| kill << @all[i][:id] if (@all[i+1][:created_on] - @all[i][:created_on]) < filter}
    @data = @all.reject{|i| kill.include? i[:id]}
  end

  def filtered_size
    @data.size
  end

  def total_size
    @all.size
  end

  def by_name
    @data.map{|i| i[:name]}.group.sort_by{|k,v| -v}
  end

  def by_month
    @data.map{|i| i[:date].month}.group
  end

  def by_week
    @data.map{|i| i[:date].cweek}.group
  end

  def by_hour
    @data.map{|i| i[:date_time].hour}.group
  end

  def by_wday
    @data.map{|i| i[:date_time].wday}.group
  end

  def longest_time
    diff = []
    (0..@data.size-2).each {|i| diff << (@data[i+1][:created_on] - @data[i][:created_on])}
    (Time.now - diff.max).time_ago_in_words.gsub(' ago', '')
  end

  def last_page
    @data.last[:created_on].time_ago_in_words
  end

  def last_update
    DB[:update].first.first.last.time_ago_in_words
  end
end


if ENV['PAGER_USER']
  USERNAME = ENV['PAGER_USER']
  PASSWORD = ENV['PAGER_PASS']
else
  require './cred'
end

module Fetcher
  extend self
  def update
    write_to_db( month( DateTime.now.month) )
    DB[:update].delete
    DB[:update].insert Time.now
  end

  def results(month, offset)
    base = "http://heroku.pagerduty.com/api/v1/incidents?service=PERV0CL"
    date_range = "from=#{Date.new(2012,month,1)}&until=#{Date.new(2012,month,-1)}"
    r = RestClient::Resource.new("#{base}&offset=#{offset}&#{date_range}",
          :user => USERNAME,
          :password => PASSWORD)
    return JSON.parse(r.get)
  end

  def month(month)
    set = results(month, 0)
    total = set['total']
    incidents = set['incidents']
    (0..total/100).each do |i|
      puts "month #{month}. Getting #{i*100} of #{total}..."
      incidents += results(month, i*100)['incidents']
    end
    incidents.select{|i| i['incident_key'] =~ /^Shogun/}
  end

  def write_to_db(incidents)
    incidents.each do |i|
      begin
        DB[:pages].insert(
          :id          => i['incident_number'],
          :created_on  => DateTime.parse(i['created_on']),
          :name        => i['last_status_change_by']['name'],
          :description => i['incident_key'] )
      rescue
        next
      end
    end
  end
end

class Array
  def group
    counter = Hash.new(0)
    self.each{|i| counter[i] += 1}
    Hash[counter.sort_by{|k,v| k}]
  end

  def pluck(key)
    map{|i| i[key]}
  end
end

