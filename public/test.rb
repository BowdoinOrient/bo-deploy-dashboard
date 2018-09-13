require 'fileutils'
thing = Dir["/home/orientweb-sync/db-sync/*.sql"].sort!.reverse![0]
FileUtils.cp(thing, "./db.sql")

File.open("./db.sql") do |source_file|
    contents = source_file.read
    contents.gsub!("bowdoinorient.com", "abcd.test.bowdoinorient.co")
    File.open("./db_mod.sql", "w+") { |f| f.write(contents) }
end
