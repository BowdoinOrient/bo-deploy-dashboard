# Bowdoin Orient Deployment Dashboard

A web-based deployment application for the Bowdoin Orient.

To be deployed on a server running Apache and [Passenger](https://www.phusionpassenger.com). Make sure to follow the [Passenger deployment instructions](https://www.phusionpassenger.com/docs/tutorials/deploy_to_production/deploying_your_app/oss/ownserver/ruby/apache/) very carefully. This application does have a Gemfile; at the appropriate time, run `bundle install` to pull down all the dependencies.

This directory should be in `/var/www/deploy`; there should also exist a `/var/www/wordpress` directory where the different environments will go.

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

The unix machine should have a group `developers` and should have users for each developer that will use the machine. Each developer account should be part of the `developers` group. The machine also assumes that:

- Git is installed
- There is a default user called `ubuntu` with `sudo` privileges
- There is a `db_sync` directory in `/home/ubuntu` with a recent SQL dump of the Bowdoin Orient database

You'll need to change `/etc/ssh/sshd_config`: here's what I added to the bottom:

```
# Allow ssh login on Bowdoin's network
Match address 139.140.0.0/16
PasswordAuthentication yes
```
