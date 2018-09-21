require 'git'
require 'rsync'
require 'sinatra'
require 'mysql2'
require 'fileutils'
require 'json'
require 'dotenv'
require "open-uri"

Dotenv.load

client = Mysql2::Client.new(:host => 'localhost', :username => 'root', :password => ENV['DB_ROOT_PW'])

def download_into_directory(dir)
    if Dir.exist?("/var/www/wordpress/#{dir}")
        raise "Directory already exists"
    end

    g = Git.clone("git@github.com:BowdoinOrient/bowpress.git", dir, :path => "/var/www/wordpress")
    FileUtils.chown("james", "developers", "/var/www/wordpress/#{dir}")
    FileUtils.chmod(0775, "/var/www/wordpress/#{dir}")
end

def delete_directory(dir)
    if !Dir.exist?("/var/www/wordpress/#{dir}")
        return
    end

    FileUtils.rm_rf("/var/www/wordpress/#{dir}")
end

def update_master
    if !Dir.exist?('/var/www/wordpress/master')
        raise "Master directory doesn't exist :("
    end

    # not the same as `git init`, instead initializing a Git obj
    g = Git.init('/var/www/wordpress/master/')
    g.checkout('master')
    g.remote('origin').fetch
    g.pull
end

def deploy_master
    update_master
    result = Rsync.run("-r", "/var/www/wordpress/master/", "./master") # Change where this rsyncs to
end

def gen_password(size = 6)
  charset = %w{ 2 3 4 6 7 9 A C D E F G H J K M N P Q R T V W X Y Z}
  (0...size).map{ charset.to_a[rand(charset.size)] }.join
end

def new_database_with_user(name)
    mysql_password = gen_password(24)
    client = Mysql2::Client.new(:host => 'localhost', :username => 'root', :password => ENV['DB_ROOT_PW'])
    client.query("CREATE DATABASE #{name}")
    client.query("CREATE USER '#{name}'@'localhost' IDENTIFIED BY '#{mysql_password}';")
    client.query("GRANT ALL PRIVILEGES ON #{name} . * TO '#{name}'@'localhost';")
    client.close

    return mysql_password
end

def delete_database_with_user(name)
    name = name.gsub(/[^a-z0-9_]/, '')
    if name == ""
        return
    end

    client = Mysql2::Client.new(:host => 'localhost', :username => 'root', :password => ENV['DB_ROOT_PW'])
    client.query("DROP DATABASE #{name};")
    client.query("DROP USER IF EXISTS '#{name}'@'localhost';")
    client.close
end

def get_newest_db_export
    Dir["/home/orientweb-sync/db-sync/*.sql"].sort!.reverse![0]
end

def clean_db_file(orig_db_backup_fname, replacement_domain)
    temp_filename = "./db_temp.sql"
    output_filename = "./db_altered.sql"

    FileUtils.cp(orig_db_backup_fname, temp_filename)

    File.open(temp_filename) do |source_file|
        contents = source_file.read
        contents.gsub!("bowdoinorient.com", replacement_domain)
        File.open(output_filename, "w+") { |f| f.write(contents) }
    end

    FileUtils.rm(temp_filename)

    return output_filename
end

def sync_db_export(db_name, replacement_domain)
    original_db_backup_filename = get_newest_db_export()
    url_cleaned_db_filename = clean_db_file(original_db_backup_filename, replacement_domain)
    system "mysql -u root -p#{ENV['DB_ROOT_PW']} #{db_name} < #{url_cleaned_db_filename}"
    FileUtils.rm(url_cleaned_db_filename)
end

def write_wpconfig(db, pw)
    uri = open("https://api.wordpress.org/secret-key/1.1/salt/")
    keys = uri.read

    File.open("./wp-config.php") do |source_file|
        contents = source_file.read
        contents.gsub!("replace_dbname", db)
        contents.gsub!("replace_dbuser", db)
        contents.gsub!("replace_dbpw", pw)
        contents.gsub!("replace_keys", keys)
        File.open("/var/www/wordpress/#{db}/wp-config.php", "w+") { |f| f.write(contents) }
    end

    FileUtils.cp("./htaccess", "/var/www/wordpress/#{db}/.htaccess")
end

get '/' do
    send_file File.join(settings.public_folder, 'index.html')
end

get '/update_master' do
    update_master
    return "done."
end

get '/deploy_master' do
    deploy_master
    return "done."
end

get '/devenvs' do
    client.query('use deploy_config')
    output = []
    envs = client.query('SELECT * FROM devenvs').each(:as => :json) do |row|
        output.push(JSON.generate(row))
    end

    return "[" + output.join(", ") + "]"
end

get '/new_devenv' do
    db = params['subdomain']
    who = params['creator']
    notes = params['notes']

    db = db.gsub(/[^a-z0-9_]/, '')
    who = who.gsub(/[^a-z0-9_]/, '')
    notes = notes.gsub(/[^a-z0-9_]/, '')

    if db == "" || who == ""
        return "failed"
    end

    download_into_directory(db)

    pw = new_database_with_user(db)
    sync_db_export(db, db + ".test.bowdoinorient.co")

    client.query("USE deploy_config")
    client.query("INSERT INTO devenvs (subdomain, creator, more_text, sql_password) VALUES ('#{db}', '#{who}', '#{notes}', '#{pw}')")

    write_wpconfig(db, pw)

    return JSON.generate(
        client.query("SELECT * FROM devenvs WHERE subdomain='#{db}'", :as => :json).first
    )
end

get '/delete_devenv' do
    db = params['subdomain']
    db = db.gsub(/[^a-z0-9_]/, '')

    if db == ""
        return "failed"
    end

    delete_directory(db)
    client.query("USE deploy_config")
    client.query("DELETE FROM devenvs WHERE subdomain='#{db}';")
    delete_database_with_user(db)
    return "done."
end
