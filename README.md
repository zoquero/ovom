# Summary

Open vCenter Operations Manager is a free software tool to manage and monitor operational state and performance of a VMware vCenter infrastructure.

It has two components:

* **Web Interface** : Perl web application that simply relies on the ancient CGI perl package
* **Core**: A perl service that uses the **vCenter Perl SDK API**, tested on 6.5.

Angel Galindo Muñoz , zoquero _at_ gmail.com

July the 16th of 2017

# Features

It's in an initial development stage but its goals are:

* (done! *v0.1*) Maintain its own **Inventory** on a local database, but it also exports entities to CSV files to ease external access
* Extract **performance metrics**:
    * (done! **v0.2**) Extract realtime performance metrics of hosts, clusters and VMs
    * (done! **v0.2**) Store them on plain CSV files
    * (done! **v0.3** & **v0.4**) Housekeep them in a **RRDB** style, but with customizable rounding parameters, improving VMware's hardsettings regarding sample interval on real-time, daily, monthly and yearly graphs.
* Show performance graphics:
    * Offer a simple Web UI to allow have graphs for custom intervals on-demand.
* Report alarms based on thresholds
* Suggest changes (initially just sugggest, later would be nice to allow to apply):
    * vMotion
    * Storage vMotion
    * Hardware scale (more or less hosts for clusters)
    * vHardware scale (more or less vCPUs for VMs)

# Some API links
* http://www.ovh.com/images/vmWorld/OVH60.pdf
* http://www.virtuallyghetto.com/2011/11/when-do-vsphere-morefs-change.html

# Installation

## vCenter Perl SDK API
https://code.vmware.com/web/sdk/65/vsphere-perl

## Packages for ovom core

A **basic perl installation**, plus some perl libs: CGI, mysql splines, gnuplot
```
$ sudo apt-get install perl libdbd-mysql-perl libwww-perl libhttp-cookies-perl libmath-spline-perl libchart-gnuplot-perl
```

Just to complement it: here's the list of packages to which belong all the files that were open by a run of picker.pl, as shown by *strace*:
```
$ sudo apt-get install base-files language-pack-es-base libc6:amd64 libdbd-mysql-perl \
       libdbi-perl libgcc1:amd64 libhttp-cookies-perl libhttp-date-perl libhttp-message-perl \
       libicu55:amd64 libio-socket-ssl-perl liblzma5:amd64 libmath-derivative-perl \
       libmath-spline-perl libmysqlclient20:amd64 libnet-http-perl libnet-ssleay-perl \
       libnss-mdns:amd64 libssl1.0.0:amd64 libstdc++6:amd64 liburi-perl libwww-perl \
       libxml2:amd64 libxml-libxml-perl libxml-sax-base-perl mysql-server-core netbase \
       openssl zlib1g:amd64
```

## Packages for ovom web interface

```
$ sudo apt-get install apache2 libcgi-session-perl
```

## Configuration for ovom web interface
```
$ sudo a2enmod cgi
$ sudo cp extra/100-owebui /etc/apache2/sites-available/100-owebui.conf
$ sudo a2ensite 100-owebui
$ sudo service apache2 restart
```

## Folders

PENDING! we'll list here the folders to be created

```
$ sudo setfacl -m user:www-data:rw- /var/log/ovom/
$ # substitute /home/agalindo/workspace/ovom/www/graphs
$ # for 'web.graphs.folder' param in conf
$ sudo setfacl -m user:www-data:rwx /home/agalindo/workspace/ovom/www/graphs

```

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

Copy **`extra/secrets.conf.sample`** in to **`secrets.conf`** and set the credentials in its variables **`OVOM_VC_USERNAME`** and **`OVOM_VC_PASSWORD`**
```
$ cp extra/secrets.conf.sample secrets.conf
```

## Database

Nowadays it just supports MySQL through Perl DBI. The changes on code would be minimum to use any other database supported by DBI.

You can use *root* MySQL user to create the database and tables and use a new dedicated user access those tables.

Configuration steps regarding database:

* Set the credentials for that new mysql user in the variables **`OVOM_DB_USERNAME`** and **`OVOM_DB_PASSWORD`** of the previously created file **`secrets.conf`**

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

# Uninstallation

* Remove authorizations (revoke grants), user and database:
```
$ mysql -u root       -prootpassword ovomdb < db/deletedb.sql 
```

# Execution

```
$ su ovom -c "\"$OVOM_BASE/picker.pl\""
```

To just run a loop:
```
$ su ovom -c "\"$OVOM_BASE/picker.pl\" --once"
```
