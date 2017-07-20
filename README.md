# Summary

Open vCenter Operations Manager is a tool to manage and monitor operational state and performance of a VMware vCenter infraestructure.

It relies upon the vCenter Perl SDK API, tested on 6.5.

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
