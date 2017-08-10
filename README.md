# Summary

Open vCenter Operations Manager is a tool to manage and monitor operational state and performance of a VMware vCenter infraestructure.

It uses the vCenter Perl SDK API, tested on 6.5.

Angel Galindo Muñoz , zoquero _at_ gmail.com

July the 16th of 2017

# Features

It's in an initial development stage but its goals are:

* Maintain its own Inventory
* Collect performance metrics:
    * Collect realtime performance metrics of hosts, clusters and VMs
    * Store them on plain files
    * Housekeep them in a RRDB style, but with customizable rounding parameters, improving VMware's hardsettings regarding sample interval on real-time, daily, monthly and yearly graphs.
* Show performance metrics:
    * Offer a simple Web UI to allow have graphs for custom intervals on-demand.
* Suggest changes:
    * vMotion
    * Storage vMotion
    * Hardware scale (more or less hosts for clusters)
    * vHardware scale (more or less vCPUs for VMs)
* Report alarms

# Development

It's in development stage. It's expected to have a release in september 2017 with at least:

* Inventory
* Collection of performance metrics
* Show performance metrics

# Some API links
* http://www.ovh.com/images/vmWorld/OVH60.pdf

# Installation

## Database

Nowadays it just supports MySQL through Perl DBI

* Setup Database configuration in **`ovom.conf`**
    * **`db.hostname`**
    * **`db.name`**
    * **`db.username`**
    * **`db.password`**

* Creation of the DataBase, the user and authorizations:

```
$ mysql -u root -p
mysql> CREATE DATABASE ovomdb;
mysql> CREATE USER 'ovomdbuser'@'localhost' IDENTIFIED BY 'ovomdbpass';
mysql> GRANT CREATE, DELETE, INSERT, SELECT, UPDATE 
             ON `ovomdb`.* TO 'ovomdbuser'@'localhost';
mysql> flush privileges;
```

* Creation of tables and initial data from scripts **`db/ddl.sql`** and **`db/data.sql`** :
```
$ mysql -u root       -prootpassword        < db/create_db.sql
$ mysql -u root       -prootpassword        < db/grants.sql
$ mysql -u root       -prootpassword ovomdb < db/ddl.sql
$ mysql -u ovomdbuser -povomdbpass   ovomdb < db/data.sql
```

# Uninstallation

* Remove authorizations (revoke grants)
* Remove user
* Remove database ( **`DROP DATABASE ovomdb`** )

