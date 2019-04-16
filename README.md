# Bowdoin Orient Deployment Dashboard

A web-based deployment application for the Bowdoin Orient.

## Why?

WordPress development has been difficult for the Orient. Setting up a WordPress development environment can be difficult, especially since the Orient' site requires so many database-specific things. This dashboard manages different development environments running on the same server. Each environment has its own local directory, database, and Git branch.

Read more about why this exists on [my blog post about the site.](https://jameslittle.me/blog/2018/developing-deploying-orient)

## How do I use it?

## How do I set it up?

The application expects to be deployed on a server running Apache and [Passenger](https://www.phusionpassenger.com). Make sure to follow the [Passenger deployment instructions](https://www.phusionpassenger.com/docs/tutorials/deploy_to_production/deploying_your_app/oss/ownserver/ruby/apache/) very carefully. This application does have a Gemfile; at the appropriate time, run `bundle install` to pull down all the dependencies.

This directory should be cloned to `/var/www/deploy`; there should also exist a `/var/www/wordpress` directory where the different environments will go.

A MySQL server is needed, with the following table in the `deploy_config` database:

```sql
CREATE TABLE `devenvs` (
  `subdomain` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `creator` varchar(255) DEFAULT NULL,
  `more_text` text,
  `sql_password` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

The server running the program must be a UNIX machine with a `devgrp` user group, and should have a `dev` user. The `dev` user, the `ubuntu` user, and the `www-data` user should be part of the `devgrp` group. The machine also assumes that:

- Git is installed
- The default user is called `ubuntu` and has `sudo` privileges
- There is a `db_sync` directory in `/home/ubuntu` with a recent SQL dump of the Bowdoin Orient database

You'll need to change `/etc/ssh/sshd_config`: here's what I added to the bottom:

```
# Allow ssh login on Bowdoin's network
Match address 139.140.0.0/16
PasswordAuthentication yes
```
