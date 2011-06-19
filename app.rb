require './history'
require 'sinatra/base'
require 'warden'
require 'warden-googleapps'

class App < Sinatra::Base
  enable :inline_templates

  use Rack::Session::Cookie
  use Warden::Manager do |manager|
    manager.default_strategies :google_apps
    manager.failure_app = App
    manager[:google_apps_domain] = 'heroku.com'
  end

  get '/' do
    throw(:warden) unless env['warden'].authenticate!

    @h = Stats.new
    erb :index
  end

  get '/update' do
    Fetcher.update
    redirect '/'
  end

  helpers do
    def format(prop)
      str = "<div>"
      str << "<h2>#{prop.to_s.gsub("_", " ")}</h2>"
      str << "<table>"
      str << "<tr><th>#{prop.to_s.split('_').last}</th><th>count</th></tr>"
      @h.send(prop).each do |k,v|
        str << "<tr><td>#{k}</td><td>#{v}</td></tr>"
      end
      str << "</table></div>"
    end
  end
end

__END__

@@index
<style>
 div {
 float: left; margin: 1em; padding: 1em; background-color: aliceblue;
 box-shadow: gray 3px 3px 3px;
 border-radius: 10px;
 }
 body {
   text-shadow: rgba(255,255,255,0.5) 0px 1px 1px;
   font-family: futura;
 }
</style>
<%= format(:by_name) %>
<%= format(:by_week) %>
<%= format(:by_hour) %>
<%= format(:by_month) %>
<%= format(:by_wday) %>
<div>
<table>
<tr><td>total count     </td><td><%= @h.total_size    %></td></tr>
<tr><td>filtered count  </td><td><%= @h.filtered_size %></td></tr>
<tr><td>longest interval</td><td><%= @h.longest_time  %><td></tr>
<tr><td>last page       </td><td><%= @h.last_page     %></td></tr>
<tr><td>last update     </td><td><%= @h.last_update   %></td></tr>
</table>
</div>
