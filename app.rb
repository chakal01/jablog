require 'bundler'
Bundler.require(:default)

require 'yaml'
# require 'sinatra/assetpack'
require "sinatra/config_file"

db = YAML.load_file('./config/database.yml')["development"]
ActiveRecord::Base.establish_connection(db)
   
class Blog < ActiveRecord::Base
  has_many :posts
end
class Post < ActiveRecord::Base
  belongs_to :blog
  has_many :images
end
class Image < ActiveRecord::Base
  belongs_to :post
end

class App < Sinatra::Base
  register Sinatra::AssetPack
  register Sinatra::ConfigFile

  config_file './config/application.yml'

  if settings.file_logger
    ::Logger.class_eval { alias :write :'<<' }
    access_log = ::File.join(::File.dirname(::File.expand_path(__FILE__)),'log','access.log')
    access_logger = ::Logger.new(access_log)
    error_logger = ::File.new(::File.join(::File.dirname(::File.expand_path(__FILE__)),'log','error.log'),"a+")
    error_logger.sync = true
  end

  set :root, File.dirname(__FILE__)

  assets do
    serve '/images', from: 'app/images'
    serve '/css', from: 'app/css'
    serve '/js', from: 'app/js'
    # serve '/fonts', from: 'app/fonts'

    js :application, ['/js/jquery.min.js', '/js/bootstrap.min.js']
    css :application, ['/css/bootstrap.min.css', '/css/app.css']

    js_compression :jsmin
    css_compression :sass
  end

  configure do
    if settings.file_logger
      use ::Rack::CommonLogger, access_logger
    end
  end

  before do
    if settings.file_logger
      env["rack.errors"] = error_logger
    end
  end

  def h(text)
    Rack::Utils.unescape(text) rescue text
  end

  get '/' do
    @title = "Blogs JAB été 2016"
    @blogs = Blog.all
    erb :main
  end
  
  get '/:blog_id' do
    @blog = Blog.find_by(url: params[:blog_id])
    redirect '/' if @blog.nil?
    @posts = @blog.posts.includes(:images)
    @title = @blog.name
    erb :blog
  end

  get '/:blog_id/:post_id' do
    @blog = Blog.find_by(url: params[:blog_id])
    redirect '/' if @blog.nil?
    @post = Post.find_by(url: params[:post_id])
    @title = @blog.name
    @posts = @blog.posts.where("id <> #{@post.id}").where(active: true).includes(:images)
    redirect "/#{@blog.id}" if @post.nil? or !@post.active
    @post.views = @post.views+1
    @post.save
    erb :post
  end

 

end