#!/usr/bin/perl -w

use strict;
use Time::Local;
use Math::BigFloat;
use Getopt::Long;
use Statistics::Descriptive;

# Print statistics
# Requires the following inputs:
#    $totaltime: total average travel time
#    $totalnum:  total number of vehicles
#    %snum:      number of vehicles per start line
#    $waiting:   number of vehicles stopped for red light
#    %vehtype:   total vehicle composition
#    %route:	 vehicle route
#    $starttime: start time as integer
#    $endtime:   end time as integer
# Requires the following subroutines
#    routeflow()    returns the relative traffic flow, input: from, to
#    vehicleflow()  returns the input flow, input: from, to
#    stats()        default statistics
#    statsvissm()   vissim statistics
#    convert()      convert line numbers into Vissim veh inp number
#    convertfile()  read from given convert file
#    timevalf()     return time as seconds.milliseconds
#    timeval()      return time as seconds

# simulation start/end
my $starttime = 0;
my $endtime = 0;

# total average travel time
my $totaltime;

# total number of vehicles
my $totalnum = 0;

# number of vehicles per start line
my %snum;

# vehicle route
my %route;

# total vehicle composition
my %vehtype;

# amount stopped at red light
my $waiting=0;

# travel time descriptive statistics
my %travel_stat_desc;

my %opt;
GetOptions(\%opt, "vissim", "convert=s", "convert-file=s");

# Data format: [completion time];[route];[veh id];[vehicle type];[travel time]
# Where [completion time] is printed with one decimal.
# [vehicle type] is a string.
# [travel time] is printed with 0 to 2 decimals.
#
# The decimal separator is a dot.
while(<>) {
	chomp;
	s/ //g;
	my ($ctime, $rt, $id, $vtype, $tt) = split(/;/);
	if (defined($tt) and ($ctime =~ /\d*\./)) {
		# Update start/endtime
		if (($ctime < $starttime) or $starttime == 0) {
			$starttime = $ctime;
		}
		if ($ctime > $endtime) {
			$endtime = $ctime;
		}

		# Average travel time
		$totaltime += $tt;
		$totalnum++;

		# Descriptive travel time statistics
		unless (exists($travel_stat_desc{$rt})) {
			$travel_stat_desc{$rt} = Statistics::Descriptive::Full->new();
		}
		$travel_stat_desc{$rt}->add_data($tt);

		# Number of vehicles per start line
		# Get start- and endline
		if ($rt =~ /(.*)->(.*)/) {
			my $sline = $1;
			my $eline = $2;
			$snum{$sline}++;
			$route{$sline}{$eline}++;
		}

		# Vehicle type
		$vehtype{$vtype}++;
	}
}

# quit if no data found
die("no valid data found\n") if ($totalnum == 0);

# Get convert information from file
convertfile() if exists($opt{"convert-file"});

if (exists($opt{vissim})) {
	statsvissim();
}
else {
	stats();
}

sub stats {
	# average travel time
	my $avgdelay = sprintf("%.2f", $totaltime / $totalnum);

	# vehicle flow: veh / hour on each starting line
	print "Incoming traffic volume:\n";
	foreach my $st (sort keys %snum) {
		print "\tline $st: ". vehicleflow($st) ."\tveh/h\n";
	}

	print "Total number of vehicles: $totalnum\n";

	# number of vehicles per starting line
	print "Number of vehicles:\n";
	foreach my $st (sort keys %snum) {
		print "\tfrom line $st: $snum{$st}\n";
	}

	print "Average travel time: " . $avgdelay ." s\n";

	print "Average travel times on all routes\n";
	foreach my $r (sort keys %travel_stat_desc) {
		printf("%s: %.2f s (min: %.1f s, max: %.1f s, variance: %.2f s, ".
			"std dev: %.2f s)\n",
			$r, $travel_stat_desc{$r}->mean(),
			$travel_stat_desc{$r}->min(),
			$travel_stat_desc{$r}->max(),
			$travel_stat_desc{$r}->variance(),
			$travel_stat_desc{$r}->standard_deviation(),
			);
	}

	if (exists($opt{waitline})) {
		print "Vehicles stopped for red light: ".
		sprintf("%.2f", (($waiting / $totalnum) * 100)) ."%\n";
	}

	print "Vehicle composition:\n";
	foreach my $v (sort keys %vehtype) {
		my $percent = Math::BigFloat->new($vehtype{$v} / $totalnum * 100);
		$percent->precision(-2);
		print "\t$v: ".$percent."%\n";
	}

	print "Vehicle endline:\n";
	foreach my $s (sort keys %snum) {
		print "\tfrom line: $s: ";
		foreach my $e (sort keys %{$route{$s}}) {
			print "to line $e: ". routeflow($s, $e) ."% ";
		}
		print "\n";
	}
}

# Vehicle flow: veh/hour on given start line
# precision as optional argument
# Sets precision to 2 decimals, unless given otherwise
sub vehicleflow {
	my $sline = shift;
	my $p = shift;
	$p = 2 unless defined($p);
	my $flow = ($snum{$sline} / ($endtime - $starttime)) * 3600;
	sprintf("%.". $p ."f", $flow);
}

# Vehicle routing decision
# Relative traffic flow, from given line, to given line
# Sets precision to 2 decimals, unless given otherwise
sub routeflow {
	my ($sline, $eline, $p) = @_;
	$p = 2 unless defined ($p);
	my $percent = ($route{$sline}{$eline} / $snum{$sline}) * 100;
	sprintf("%.". $p ."f", $percent);
}

# Statistics to vissim
sub statsvissim {
	my @text;
	print "input=";
	foreach my $st (sort keys %snum) {
		my $flow = vehicleflow($st, 0);
		$st = convert($st) if exists($opt{convert});
		push @text, "$st=$flow";
	}
	print join ",", @text;
	@text = ();
	print "\nroute=";
	foreach my $s (sort keys %snum) {
		foreach my $e (sort keys %{$route{$s}}) {
			my $flow = routeflow($s, $e, 0);
			my $route = "$s:$e";
			$route = convert($route) if exists($opt{convert});
			push @text, "$route=$flow";
		}
	}
	print join ",", @text;
}

# Convert line numbers into Vissim veh inp number
sub convert {
	my $line = shift;
	my @convertline = split /,/, $opt{convert};
	foreach my $conversion (@convertline) {
		my ($l, $i) = split /=/, $conversion;
		return $i if ($line eq $l);
	}
}

# Read from given convert file
sub convertfile {
	open(CFILE, $opt{"convert-file"}) or
		die "Could not open convert file\n";
	my @co;
	while (<CFILE>) {
		chomp;
		s/( |\t)//g;
		push @co, $_ unless(/^(#|$)/);
	}
	$opt{convert} = join(',', @co);
	close CFILE;
}

# Return time as seconds.milliseconds
sub timevalf {
	my ($hour, $min, $sec, $msec) = split /:/, shift;
	my $result= timelocal($sec, $min, $hour, 1, 1, 1) . "." . $msec;
	Math::BigFloat->new($result);
}

# Return time as seconds
sub timeval {
	my ($hour, $min, $sec, $msec) = split /:/, shift;
	timelocal($sec, $min, $hour, 1, 1, 1);
}

__END__

=head1 NAME

ttstat - travel time statistics

=head1 SYNOPSIS

B<ttstat.pl> --vissim --convert --convert-file

=head1 DESCRIPTION

ttstat.pl prints various forms of statistics from travel times.

travel times is read on the form

[completion time];[route];[veh id];[vehicle type];[travel time]

=head1 OPTIONS

--vissim

Output traffic volume and routing relative flow in a format compatible with
B<visperl.pl>

--convert

Convert line numbers present in the Sava input data to Vissim veh inp
numbers. e.g. 1=4 to turn line number 1 into Vissim veh inp 4.
Separate each conversion with a comma. e.g. --convert 1=4,4=32
Note: This option only works in combination with the B<--vissim> option.

--convert-file

Read sava line to vissim input-/desc/route no from a file. See B<--convert>
Separate each conversion with a new line. Lines beginning with a '#'
-character is considered a comment.
Note: This option only works in combination with the B<--vissim> option.

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.com>

==cut
