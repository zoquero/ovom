# Summary

Open vCenter Operations Manager is a free software tool to manage and monitor operational state and performance of a VMware vCenter infrastructure.

It uses the vCenter Perl SDK API, tested on 6.5.

Angel Galindo Muñoz , zoquero _at_ gmail.com

July the 16th of 2017

# Features

It's in an initial development stage but its goals are:

* Maintain its own Inventory
* Extract performance metrics:
    * Extract realtime performance metrics of hosts, clusters and VMs
    * Store them on plain CSV files
    * Housekeep them in a RRDB style, but with customizable rounding parameters, improving VMware's hardsettings regarding sample interval on real-time, daily, monthly and yearly graphs.
* Show performance graphics:
    * Offer a simple Web UI to allow have graphs for custom intervals on-demand.
* Report alarms based on thresholds
* Suggest changes:
    * vMotion
    * Storage vMotion
    * Hardware scale (more or less hosts for clusters)
    * vHardware scale (more or less vCPUs for VMs)

# Development

It's in development stage. It's expected to have a release in september 2017 with at least:

* (done! v0.1) Inventory 
* Extraction of performance metrics (work in progress)
* Show performance graphics
* Report alarms

# Some API links
* http://www.ovh.com/images/vmWorld/OVH60.pdf

# Installation

## User

```
$ OVOM_BASE=/opt/ovom
$ sudo mkdir "$OVOM_BASE"
$ sudo groupadd ovom
$ sudo useradd -c "OVOM software" -d /opt/ovom -g ovom -s `which bash`
```

## Files
Save this project somewhere like /opt/ovom/ . Let's call it 'OVOM_BASE':

```
$ git clone https://github.com/zoquero/ovom
$ sudo mv ovom/*  "$OVOM_BASE"
$ sudo mv ovom/.* "$OVOM_BASE"
$ sudo rmdir ovom
$ sudo chown -R ovom:ovom "$OVOM_BASE"
```


## vCenter access
By now it just needs inventory access. A role like *Read-only* would be more than enough. In future releases it may need permissions for vMotion and Storage vMotion.

Just set the credentials in the environment variables **`OVOM_VC_USERNAME`** and **`OVOM_VC_PASSWORD`**

## Database

Nowadays it just supports MySQL through Perl DBI. The changes on code would be minimum to use any other database supported by DBI.

You can use *root* MySQL user to create the database and tables and use a new dedicated user access those tables.

Configuration steps regarding database:

* Set the credentials for that new mysql user in the environment variables **`OVOM_DB_USERNAME`** and **`OVOM_DB_PASSWORD`**

* Set the database configuration in the file **`ovom.conf`**:
    * **`db.hostname`**
    * **`db.name`**

* Create of database, user, grants, tables and initial data:
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

# Execution

```
$ su ovom -c "OVOM_DB_USERNAME=ovomdbuser  \
              OVOM_DB_PASSWORD=ovomdbpass  \
              OVOM_VC_USERNAME=vcenteruser \
              OVOM_VC_PASSWORD=vcenterpass \"$OVOM_BASE/picker.pl\""
```

To just ron a loop:
```
$ su ovom -c "OVOM_DB_USERNAME=ovomdbuser  \
              OVOM_DB_PASSWORD=ovomdbpass  \
              OVOM_VC_USERNAME=vcenteruser \
              OVOM_VC_PASSWORD=vcenterpass \"$OVOM_BASE/picker.pl\" --once"
```
