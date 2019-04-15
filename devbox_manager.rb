require 'git'
require 'rsync'
require 'sinatra'
require 'mysql2'
require 'sudo'
require 'fileutils'
require 'json'
require 'dotenv'
require "open-uri"

Dotenv.load

client = Mysql2::Client.new(:host => 'localhost', :username => 'root', :password => ENV['DB_ROOT_PW'])

def download_into_directory(dir)
    if Dir.exist?("/var/www/wordpress/#{dir}")
        FileUtils.rm_rf("/var/www/wordpress/#{dir}")
    end

    g = Git.clone("git@github.com:BowdoinOrient/bowpress.git", dir, :path => "/var/www/wordpress")
    g.config('core.fileMode', 'false')
    g.branch(dir).checkout
end

def delete_directory(dir)
    if Dir.exist?("/var/www/wordpress/#{dir}")
        FileUtils.rm_rf("/var/www/wordpress/#{dir}")
    end
end

def update_master
    if !Dir.exist?('/var/www/wordpress/master')
        return
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
    client.query("DROP DATABASE IF EXISTS #{name};")
    client.query("DROP USER IF EXISTS '#{name}'@'localhost';")
    client.query("CREATE DATABASE #{name}")
    client.query("CREATE USER '#{name}'@'localhost' IDENTIFIED BY '#{mysql_password}';")
    client.query("GRANT ALL PRIVILEGES ON #{name} . * TO '#{name}'@'localhost';")
    client.close

    return mysql_password
end

def delete_database_with_user(name)
    name = name.gsub(/[^a-z0-9]/, '')
    if name == ""
        return "Invalid database name"
    end

    client = Mysql2::Client.new(:host => 'localhost', :username => 'root', :password => ENV['DB_ROOT_PW'])
    client.query("DROP DATABASE IF EXISTS #{name};")
    client.query("DROP USER IF EXISTS '#{name}'@'localhost';")
    client.close
end

def get_newest_db_export
    Dir["/home/ubuntu/db-sync/*.sql"].sort!.reverse![0]
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

    File.open("./wp-config.txt") do |source_file|
        contents = source_file.read
        contents.gsub!("replace_dbname", db)
        contents.gsub!("replace_dbuser", db)
        contents.gsub!("replace_dbpw", pw)
        contents.gsub!("replace_keys", keys)
	
    File.open("/var/www/wordpress/#{db}/wp-config.php", "w+") { |f| f.write(contents) }
    FileUtils.cp("./htaccess.txt", "/var/www/wordpress/#{db}/.htaccess")
    end
end

def fix_directory_permissions(db)
    Sudo::Wrapper.run do |sudo|
        sudo[FileUtils].chown_R("www-data", "devgrp", "/var/www/wordpress/#{db}")
        sudo[FileUtils].chmod_R(0775, "/var/www/wordpress/#{db}")
    end
end

############ ^ Helper functions ############
################ Endpoints v ###############

get '/' do
    send_file File.join(settings.public_folder, 'index.html')
end

get '/update_master' do
    begin
        update_master
    rescue StandardError => e
        return [500, e.message]
    end
    return [200, "Master updated"]
end

get '/deploy_master' do
    begin
        deploy_master
    rescue StandardError => e
        return [500, e.message]
    end
    return [200, "Master deployed"]
end

get '/devenvs' do
    begin
        client.query('use deploy_config')
        output = []
        envs = client.query('SELECT * FROM devenvs').each(:as => :json) do |row|
            output.push(JSON.generate(row))
        end
        return "[" + output.join(", ") + "]"
    rescue StandardError => e
        return [500, e.message]
    end
end

get '/new_devenv' do
    db = params['subdomain']
    notes = params['notes']

    db = db.gsub(/[^a-z0-9]/, '')
    notes = notes.gsub(/[\"\'\;]/, '')

    if db == ""
        return [500, "Invalid database name."]
    end

    begin
        download_into_directory(db)
        pw = new_database_with_user(db)
        sync_db_export(db, db + ".test.bowdoinorient.co")

        client.query("USE deploy_config")
        client.query("INSERT INTO devenvs (subdomain, creator, more_text, sql_password) VALUES ('#{db}', 'nobody', '#{notes}', '#{pw}')")

        write_wpconfig(db, pw)
        fix_directory_permissions(db)

        return JSON.generate(
            client.query("SELECT * FROM devenvs WHERE subdomain='#{db}'", :as => :json).first
        )
    rescue StandardError => e
        return [500, e.message]
    end
end

get '/delete_devenv' do
    db = params['subdomain']
    db = db.gsub(/[^a-z0-9]/, '')

    if db == ""
        return [500, "Invalid database name."]
    end

    begin
        delete_directory(db)
        client.query("USE deploy_config")
        client.query("DELETE FROM devenvs WHERE subdomain='#{db}';")
        delete_database_with_user(db)
        return "Deleted #{db}"
    rescue StandardError => e
        return [500, e.message]
    end
end
