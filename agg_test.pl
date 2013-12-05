#!/usr/bin/perl

# Test AggregateTrafficData
use strict;
use AggregateTrafficData;

my $agg = AggreagateTrafficData->new();

# 1, Set manual data
print "Set manual data\n";
$agg->set_manual_data("manual_data.conf");

# 2, Set API-data
print "Set API-data..."; $| = 1;
$agg->overwrite();
$agg->set_api_time_period("16:00", "16:30");
$agg->run_api_control_file("apicontrol");
print "done\n";

# 3, Set SAVA-data
print "Set Sava-data\n";
$agg->no_overwrite();
$agg->set_sava_settings("1,2,3,4,5,8", "1,2,3,4,6,7,9",
		"linkoping_line_to_vehinp");
$agg->run_sava_file("savafiles.conf");

# 4, Update routing using SAVA and API
print "Update routing using SAVA and API\n";
$agg->sava_route_update("savafiles.conf");

# 5, print results
print "Print results\n";
$agg->print_all();

