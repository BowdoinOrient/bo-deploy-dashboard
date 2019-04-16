# Manual Test Suite

_All the following should be able to happen without any errors._

1. Create a devenv. Delete it. Create a devenv with that same name.
2. Open the site associated with that devenv. It should load to the Orient home page.
3. Install a plugin. FTP dialog should not appear.
4. Rsync down, make a file change, and rsync up. File change should be visible and rsync should not have failed.
5. On your local machine, run `git status`. The only changes that should appear should be the plugin installation and the file change you made.