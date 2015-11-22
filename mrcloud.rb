#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'json'
require 'yaml'
require 'optparse'
require 'find'

class HTTP_Cloud
  def initialize
    @settings_file = ENV['HOME'] + '/.mrcloud.yml'

    @agent = Mechanize.new
    @agent.cookie_jar.load ENV['HOME'] + '/cookies.yml' rescue puts 'No cookies.yml'
    @agent.user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.80 Safari/537.36'
    @agent.follow_meta_refresh = true
  end

  def set_user username, password
    @settings['username'] = username
    @settings['password'] = password
    @settings['domain'] = username.split('@')[1]
    save_settings
  end

  def login
    url = 'https://auth.mail.ru/cgi-bin/auth'
    params = { 'page' => 'https://cloud.mail.ru', 'Login' => @settings['username'], 'Password' => @settings['password'], 'Domain' =>  @settings['domain'] }
    p @agent.post(url, params)
    @agent.cookie_jar.save_as ENV['HOME'] + '/cookies.yml'
    get_token
  end

  def load_settings
    begin
      @settings = YAML.load_file(@settings_file)
    rescue Errno::ENOENT
      File.open(@settings_file,'w')
    end
    @settings = Hash.new if @settings.empty?
  end

  def save_settings
    File.open(@settings_file, "w") do |file|
      file.write @settings.to_yaml
    end
  end

  def get_token
    url = 'https://cloud.mail.ru/api/v2/tokens?'
    params = { 'email' => @settings['username'] }

    json = JSON.parse( @agent.post(url, params).body )
    @settings['token'] = json['body']['token']
    save_settings
  end

  def create_folder folder
    url = 'https://cloud.mail.ru/api/v2/folder/add'
    params = { 
      'home' => folder,
      'api' => 2,
      'email' => @settings['username'],
      'token' => @settings['token'],
      }
    p params
    begin
      @agent.post(url, params)
    rescue Mechanize::ResponseCodeError => exception
      p 'Folder is exists' if exception.response_code == '400'
    end
  end

  def remove path
    url = 'https://cloud.mail.ru/api/v2/file/remove'
    params = {
      'home' => path,
      'api' => 2,
      'email' => @settings['username'],
      'token' => @settings['token'],
      }
    p params
    @agent.post(url, params)
  end

  def upload_file local_file, remote_path
    url = 'https://dispatcher.cloud.mail.ru/u'
    server = @agent.get(url).body.split(' ')[0] #cloclo server
    p server
    p local_file
    p remote_path
    hash, name, size = File.open(local_file) do |file|
      params = { 'file' => file, }
      @agent.post(server, params).body.chomp.split(';')
    end
    add_file hash, name, size, remote_path
  end

  def upload_folder local_folder, remote_path
    dirname = File.basename local_folder
    relpath_locdir = File.expand_path local_folder

    Find.find local_folder do |file|
      if FileTest.file? file
        relpath_file = File.expand_path(file).sub(relpath_locdir, '')
        relpath_remdir = dirname + remote_path + File.dirname(relpath_file)

        upload_file dirname + relpath_file, relpath_remdir
      end
    end
  end

  def add_file hash, name, size, remote_path
    p remote_path

    # Set custom filename
    remote_path += name if remote_path[-1] == '/'

    url = 'https://cloud.mail.ru/api/v2/file/add'
    params = {
      'home' => remote_path,
      'hash' => hash,
      'size' => size,
      'api' => 2,
      'email' => @settings['username'],
      'token' => @settings['token'],
      }
    p params
    begin
      @agent.post(url, params)
    rescue Mechanize::ResponseCodeError => exception
      p 'File is exists' if exception.response_code == '400'
    end
  end

  def publish path
    url = 'https://cloud.mail.ru/api/v2/file/publish'
    params = {
      'home' => path,
      'api' => 2,
      'email' => @settings['username'],
      'token' => @settings['token'],
      }
    hash_name = JSON.parse( @agent.post(url, params).body )['body']
    puts 'https://cloud.mail.ru/public/' + hash_name
    puts 'https://cloclo15.cloud.mail.ru/weblink/thumb/xw1/' + hash_name
  end
end

cloud = HTTP_Cloud.new
cloud.load_settings

OptionParser.new do |opts|
  opts.banner = "Usage: cmr [options]"
  opts.separator ""
  opts.separator "Specific options:"

  opts.on( '-r', '--remove [PATH]', 'Remove file or folder' ) do |path|
    cloud.remove path
  end
  opts.on( '-l', '--login [PASSWORD', 'Login' ) do |password|
    cloud.login
  end
  opts.on( '-c', '--create [PATH]', 'Create folder' ) do |folder|
    cloud.create_folder folder
  end
  opts.on( '-p', '--publish [PATH]', 'Publish file or folder' ) do |path|
    cloud.publish path
  end
  opts.on( '-s', '--setuser username,password', Array, 'Set username and password' ) do |user|
    username = user[0]
    password = user[1]
    cloud.set_user username, password
  end
  opts.on( '-u', '--upload local_path,remote_path', Array, 'Upload file' ) do |args|
    local_path = args[0]
    remote_path = args[1] ? args[1] : '/' #Set as empty if path not received
    ftype = File.ftype local_path rescue puts 'Wrong local path'
    cloud.get_token
    case ftype
    when 'file'
      cloud.upload_file local_path, remote_path
    when 'directory'
      cloud.upload_folder local_path, remote_path
    end
  end
end.parse!
