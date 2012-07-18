require 'restclient'
require 'sequel'
require 'json'

DB = Sequel::Database.connect(ENV["DATABASE_URL"])

class Array
  def group
    counter = Hash.new(0)
    self.each{|i| counter[i] += 1}
    Hash[counter.sort_by{|k,v| k}]
  end
end

module DuckUp
  extend self
  def update_all
    update_leaderboard
  end

  def by_page_weeks(weeks)
     DB[:pages].select(:description).filter('created_on > ?', Date.today - weeks*7).all.
       reject{|row| row[:description].nil?}.map { |row|
         desc = row[:description]
         desc.gsub!(/Shogun:?\s?/,'')
         desc.gsub!(/#\[.+\Z/,'')
         desc.gsub!(/http.+\Z/,'')
         desc.gsub!(/resource.+\Z/,'')
         desc.gsub!(/app.+\Z/,'')
         desc.gsub!(/server-.+\Z/,'')
         desc.gsub!(/\ss\w\w\d/,'')  # sdf2
         desc.gsub!(/\son/,'')
         desc.gsub!(/:?\s+\Z/,'')
         desc }.group
  end

  def leader_format
    result = by_page_weeks(8).map{|(name,value)| {"name" => name, "values" => [value]} }
    four = by_page_weeks(4)
    one = by_page_weeks(1)
    result.each do |page|
      name = page['name']
      page['values'].unshift four[name] || 0
      page['values'].unshift one[name] || 0
    end
    sorted = result.sort_by{|h| v = h['values']; v[0]*10 + v[1]}.reverse
    {"board" => sorted}
  end

  def leader_url
    url(66619)
  end

  def url(id)
    "https://#{ENV['DUCKSBOARD_API_KEY']}:x@push.ducksboard.com/v/#{id}"
  end

  def value(v)
    JSON.dump({"value" => v})
  end

  def page_counts
    ['8 weeks', '4 weeks', '1 week', '1 day'].map do |int|
      DB[:pages].select(:description).filter('created_on > ?', "now() - '#{int}'::interval".lit).count
    end
  end


  def post_page_counts
    counts = page_counts.map{|c| value(c)}
    RestClient.post( url(66657), counts[0] )
    RestClient.post( url(66656), counts[1] )
    RestClient.post( url(66655), counts[2] )
    RestClient.post( url(66654), counts[3] )
  end


  def by_day
    DB[%Q(select extract(epoch from date_trunc('day',  created_on) + '12 hours'::interval)::int as timestamp, count(*) as value from pages group by 1 order by 1 desc limit 31;)].all
  end

  def post_by_day
    RestClient.post( url(66658), JSON.dump(by_day) )
  end


  def post
    RestClient.post(leader_url, value(leader_format))
    post_page_counts
    post_by_day
  end
end

DuckUp.post

