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

## Credentials to access vCenter
By now it just needs inventory access. A role like *Read-only* would be more than enough. In future releases it may need permissions for vMotion and Storage vMotion.

Set the credentials in the environment variables **`OVOM_VC_USERNAME`** and **`OVOM_VC_PASSWORD`**

## Database

Nowadays it just supports MySQL through Perl DBI.

You can use root MySQL user to create the database and tables and use a new dedicated user access those tables.

*  Set the credentials for that new user in the environment variables **`OVOM_DB_USERNAME`** and **`OVOM_DB_PASSWORD`**

* Setup Database configuration in **`ovom.conf`**:
    * **`db.hostname`**
    * **`db.name`**

* Creation of database, user, grants, tables and initial data:
```
$ mysql -u root       -prootpassword        < db/create_db.sql
$ mysql -u root       -prootpassword        < db/grants.sql
$ mysql -u root       -prootpassword ovomdb < db/ddl.sql
$ mysql -u root       -prootpassword ovomdb < db/data.sql
```

## Run sample

```
Ex.:
$ OVOM_DB_USERNAME=ovomdbuser  \
  OVOM_DB_PASSWORD=ovomdbpass  \
  OVOM_VC_USERNAME=vcenteruser \
  OVOM_VC_PASSWORD=vcenterpass ./testdao.pl 
```

# Uninstallation

* Remove authorizations (revoke grants), user and database:
```
$ mysql -u root       -prootpassword ovomdb < db/deletedb.sql 
```

