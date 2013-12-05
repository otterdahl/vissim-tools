
package TravelTimeStats;
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
#    convert()      convert line numbers into Vissim veh inp number
#    convertfile()  read from given convert file
#    timevalf()     return time as seconds.milliseconds
#    timeval()      return time as seconds

# waiting - not working, no supporting infrastructure
#           but it's not used very much anyway

my %fields = (
	# simulation start/end
	starttime	=> 0,
	endtime		=> 0,
	# total average travel time
	totaltime	=> 0,
	# total number of vehicles
	totalnum	=> 0,
	# HASH number of vehicles per start line
	snum		=> undef,
	# HASH vehicle route
	route		=> undef,
	# HASH total vehicle composition
	vehtype		=> undef,
	# amount stopped at red light
	waiting		=> 0,
	# HASH travel time descriptive statistics
	travel_stat_desc => undef,
	# HASH route travel time descriptive statistics
	travel_route_stat_dec => undef,
	# HASH Options
	opt			=> undef,
);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = { %fields };
	bless ($self, $class);
	return $self;
}

sub set_all_data {
	my $self = shift;
	my $line;
	while($line = shift) {
		$self->setdata($line);
	}
}

# Data format: [completion time];[route];[veh id];[vehicle type];[travel time]
# Where [completion time] is printed with one decimal.
# [vehicle type] is a string.
# [travel time] is printed with 0 to 2 decimals.
#
# The decimal separator is a dot.
sub setdata {
	my $self = shift;
	my $line = shift;
	chomp($line);
	$line =~ s/ //g;
	my ($ctime, $rt, $id, $vtype, $tt) = split(/;/, $line);
	if (defined($tt) and ($ctime =~ /\d*\./)) {
		# Update start/endtime
		if (($ctime < $self->{starttime}) or $self->{starttime} == 0) {
			$self->{starttime} = $ctime;
		}
		if ($ctime > $self->{endtime}) {
			$self->{endtime} = $ctime;
		}

		# Average travel time
		$self->{totaltime} += $tt;
		$self->{totalnum}++;

		# Get proper route name
		$rt = $self->get_route_name($rt);

		# Get route type, for separate stats
		my $rtype = $self->get_route_type($rt);

		# Descriptive travel time statistics (for route name)
		unless (exists($self->{travel_stat_desc}->{$rt})) {
			$self->{travel_stat_desc}->{$rt} = Statistics::Descriptive::Full->new();
		}
		$self->{travel_stat_desc}->{$rt}->add_data($tt);

		# Descriptive travel time statistics (for route type)
		if (defined($rtype)) {
			unless (exists($self->{travel_type_stat_desc}->{$rtype})) {
				$self->{travel_type_stat_desc}->{$rtype} = Statistics::Descriptive::Full->new();
			}
			$self->{travel_type_stat_desc}->{$rtype}->add_data($tt);
		}

		# Number of vehicles per start line
		# Get start- and endline
		if ($rt =~ /(.*)->(.*)/) {
			my $sline = $1;
			my $eline = $2;
			$self->{snum}->{$sline}++;
			$self->{route}->{$sline}{$eline}++;
		}

		# Vehicle type
		$self->{vehtype}{$vtype}++;
	}
	return 1;
}

# Sets RSZ file, this is used in order to convert a Vissim section
# number into a route name, eg. "4->2"
sub set_rsz {
	my $self = shift;
	my $rsz = shift;
	$self->{rsz} = $rsz;
}

sub all_stats {
	my $self = shift;
	if ($self->{totalnum} == 0) {
		print "No statistics found\n";
		return undef;
	}
	$self->vehicle_flow();
	$self->total_number_of_vehicles();
	$self->number_of_vehicles_per_starting_line();
	$self->average_travel_time();
	$self->average_travel_times_on_all_routes_table();
	$self->vehicles_stopped_for_red_light();
	$self->vehicle_composition();
	$self->vehicle_endline();
}

sub vehicle_flow {
	my $self = shift;
	# vehicle flow: veh / hour on each starting line
	print "Incoming traffic volume:\n";
	foreach my $st (sort keys %{$self->{snum}}) {
		print "\tline $st: ". $self->vehicleflow($st) ."\tveh/h\n";
	}
}

sub total_number_of_vehicles {
	my $self = shift;
	print "Total number of vehicles: ". $self->{totalnum} ."\n";
}

sub number_of_vehicles_per_starting_line {
	my $self = shift;
	# number of vehicles per starting line
	print "Number of vehicles:\n";
	foreach my $st (sort keys %{$self->{snum}}) {
		print "\tfrom line $st: ". $self->{snum}{$st} ."\n";
	}
}

sub average_travel_time {
	my $self = shift;
	# average travel time
	my $avgdelay = sprintf("%.2f", $self->{totaltime} / $self->{totalnum});
	print "Average travel time: " . $avgdelay ." s\n";
}

sub average_travel_times_on_all_routes {
	my $self = shift;
	print "Average travel times on all routes:\n";
	foreach my $r (sort keys %{$self->{travel_stat_desc}}) {
		# If only one travel has been made, ignore
		# variance and standard deviation
		unless (defined($self->{travel_stat_desc}->{$r}->variance())) {
			printf("%s: %.2f s (min: %.1f s, max: %.1f s)\n",
				$r,
				$self->{travel_stat_desc}->{$r}->mean(),
				$self->{travel_stat_desc}->{$r}->min(),
				$self->{travel_stat_desc}->{$r}->max(),
			);
		}
		else {
			printf("%s: %.2f s (min: %.1f s, max: %.1f s, ".
				"variance: %.2f s, ".
				"std dev: %.2f s)\n",
				$r,
				$self->{travel_stat_desc}->{$r}->mean(),
				$self->{travel_stat_desc}->{$r}->min(),
				$self->{travel_stat_desc}->{$r}->max(),
				$self->{travel_stat_desc}->{$r}->variance(),
				$self->{travel_stat_desc}->{$r}->standard_deviation(),
			);
		}
	}
}

# Print travel time stats for each route in table form
# take the table title as argument
sub average_travel_times_on_all_routes_table {
	my $self = shift;
	my $title = shift;
	unless (defined($title)) {
		$title = "Travel times on all routes (in seconds)";
	}

	my ($route, $count, $mean, $min, $max, $variance, $stddev);
	$~ = "TOP";
	write();

	# For route name
	foreach my $r (sort keys %{$self->{travel_stat_desc}}) {
		$route = $r;
		$count = $self->{travel_stat_desc}->{$r}->count();
		$mean = $self->{travel_stat_desc}->{$r}->mean();
		$min = $self->{travel_stat_desc}->{$r}->min();
		$max = $self->{travel_stat_desc}->{$r}->max();
		$variance = $self->{travel_stat_desc}->{$r}->variance();
		$stddev = $self->{travel_stat_desc}->{$r}->standard_deviation();
		# If only one travel has been made, ignore
		# variance and standard deviation
		unless (defined($self->{travel_stat_desc}->{$r}->variance())) {
			$variance = "-";
			$stddev = "-";
			$~ = "TRAVEL";
			write();
		}
		else {
			$~ = "TRAVEL";
			write();
		}
	}
	$~ = "BOTTOM";
	write();

	# For route type
	foreach my $r (sort keys %{$self->{travel_type_stat_desc}}) {
		$route = $r;
		$count = $self->{travel_type_stat_desc}->{$r}->count();
		$mean = $self->{travel_type_stat_desc}->{$r}->mean();
		$min = $self->{travel_type_stat_desc}->{$r}->min();
		$max = $self->{travel_type_stat_desc}->{$r}->max();
		$variance = $self->{travel_type_stat_desc}->{$r}->variance();
		$stddev = $self->{travel_type_stat_desc}->{$r}->standard_deviation();
		# If only one travel has been made, ignore
		# variance and standard deviation
		unless (defined($self->{travel_type_stat_desc}->{$r}->variance())) {
			$variance = "-";
			$stddev = "-";
			$~ = "TRAVEL";
			write();
		}
		else {
			$~ = "TRAVEL";
			write();
		}
	}
	$~ = "BOTTOM";
	write();


format TOP =
@|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$title
+----------------------------------------------------------------+
| route  | count | mean |  min   |  max   | variance | std. dev. |
+--------|-------|------|--------|--------|----------|-----------+
.

format TRAVEL =
| @||||| | @#### | @#.# | @##.## | @##.## |  @##.##  |   @#.##   |
 $route,  $count,  $mean, $min,    $max,    $variance,   $stddev
.

format BOTTOM =
+----------------------------------------------------------------+
.
}

sub vehicles_stopped_for_red_light {
	my $self = shift;
	if (exists($self->{opt}{waitline})) {
		print "Vehicles stopped for red light: ".
		sprintf("%.2f", (($self->{waiting} / $self->{totalnum}) * 100)) ."%\n";
	}
}

sub vehicle_composition {
	my $self = shift;
	print "Vehicle composition:\n";
	foreach my $v (sort keys %{$self->{vehtype}}) {
		my $percent = Math::BigFloat->new($self->{vehtype}{$v} / $self->{totalnum} * 100);
		$percent->precision(-2);
		print "\t$v: ".$percent."%\n";
	}
}

sub vehicle_endline {
	my $self = shift;
	print "Vehicle endline:\n";
	foreach my $s (sort keys %{$self->{snum}}) {
		print "\tfrom line: $s: ";
		foreach my $e (sort keys %{$self->{route}{$s}}) {
			print "to line $e: ". $self->routeflow_percent($s, $e) ."% ";
		}
		print "\n";
	}
}

# Vehicle flow: veh/hour on given start line
# precision as optional argument
# Sets precision to 2 decimals, unless given otherwise
sub vehicleflow {
	my ($self, $sline, $p) = @_;
	$p = 2 unless defined($p);
	my $period = $self->{endtime} - $self->{starttime};
	my $flow = ($self->{snum}{$sline} / $period) * 3600;
	sprintf("%.". $p ."f", $flow);
}

# Vehicle routing decision
# Traffic flow, from given line, to given line as absolute number of veh
# Sets precision to 2 decimals, unless given otherwise
sub routeflow {
	my ($self, $sline, $eline, $p) = @_;
	$p = 2 unless defined ($p);
	
	# Return number of veh
	sprintf("%.". $p ."f", $self->{route}{$sline}{$eline});
}

# Vehicle routing decision
# Relative traffic flow, from given line, to given line as percent
# Sets precision to 2 decimals, unless given otherwise
sub routeflow_percent {
	my ($self, $sline, $eline, $p) = @_;
	$p = 2 unless defined ($p);

	my $percent = ($self->{route}{$sline}{$eline} / $self->{snum}{$sline}) * 100;
	sprintf("%.". $p ."f", $percent);
}

# Return vehicle input flows as a hash
sub stats_input {
	my $self = shift;
	my %flows;
	foreach my $st (keys %{$self->{snum}}) {
		my $flow = $self->vehicleflow($st, 0);
		$st = $self->convert($st);
		$flows{$st} = $flow;
	}
	return \%flows;
}

sub stats_route {
	my $self = shift;
	my %routes;
	foreach my $dec (keys %{$self->{snum}}) {
		foreach my $rt (keys %{$self->{route}{$dec}}) {
			my $route = $self->convert("$dec:$rt");
			$routes{$route} = $self->routeflow($dec, $rt, 0);
		}
	}
	return \%routes;
}

sub set_convert {
	my $self = shift;
	my $c = shift;
	if (defined($c)) {
		$self->{opt}{convert} = $c;
	}
	else {
		delete $self->{opt}{convert};
	}
}

# Convert line numbers into Vissim veh inp number
sub convert {
	my $self = shift;
	my $number = shift;
	return $number unless (exists($self->{opt}{convert}));
	my @convertline = split /,/, $self->{opt}{convert};
	foreach my $conversion (@convertline) {
		my ($l, $i) = split /=/, $conversion;
		return $i if ($number eq $l);
	}
}

# Read from given convert file
# Isn't used, but should it be?
# TODO: Used by visperl.pl
sub set_convertfile {
	my $self = shift;
	my $file = shift;
	unless (defined($file)) {
		return undef;
	}
	$self->{opt}{"convert-file"} = $file;
	open(CFILE, $self->{opt}{"convert-file"}) or
		die "Could not open convert file\n";
	my @co;
	while (<CFILE>) {
		chomp;
		s/( |\t)//g;
		push @co, $_ unless(/^(#|$)/);
	}
	$self->{opt}{convert} = join(',', @co);
	close CFILE;
}

sub route_type_file {
	my $self = shift;
	my $route_file = shift;
	open(RFILE, $route_file) or die "Could not open route file\n";
	while(<RFILE>) {
		chomp;
		s/( |\t)//g;
		unless(/^(#|$)/) {
			my ($route, $name) = split /=/, $_;
			$self->{"route-name"}{$route} = $name;
		}
	}
	close RFILE;
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

# Get route name from Vissim rsz section nr
sub get_route_name {
	my $self = shift;
	my $section_nr = shift;

	# If the rsz file hasn't been defined
	# just return what we got
	unless (exists($self->{rsz})) {
		return $section_nr;
	}

	my @travelname;
	my @traveltime;
	open(RSZ, $self->{rsz});
	while(<RSZ>) {
		chomp;
		s/ //g;
		@travelname = split(/;/) if(/^Name;/);
		@traveltime = split(/;/) if(/^No.:;/);
	}
	close RSZ;

	for (my $i=0; $i<$#traveltime; $i++) {
		if ($traveltime[$i] eq $section_nr) {
			return $travelname[$i];
		}
	}
	return $section_nr;
}

# Get route type
sub get_route_type {
	my $self = shift;
	my $route = shift;
	return $self->{"route-name"}{$route};
}

1;
__END__

=head1 NAME

TravelTimeStats - Module of travel time statistical functions.

=head1 SYNOPSIS

=over

=item use TravelTimeStats;

=item $stat = TravelTimeStats->new();

=item $stat->set_all_data(@traveltimes);

=item $stat->set_rsz($rszfilename);

=item $stat->all_stats();

=back

B<ttstat.pl> --convert --convert-file

=head1 DESCRIPTION

This module prints various forms of statistics from vehicle travel times.

Travel times is read on the form

[completion time];[route];[veh id];[vehicle type];[travel time]

Common inputs is either Vissim rsr-files or travel times produced by the
Sava2TravelTime module.

=head1 METHODS

=over

=item $tt = TravelTimeStats->new();

Create a new travel time object.

=item $tt->set_all_data($traveltime1, $traveltime2, ...);

Adds all travel time data at once.

=item $tt->setdata($traveltime);

Add a single travel time.

=item $tt->set_rsz("file.rsz");

Sets RSZ file. RSZ files are generated by Vissim and can be used in order to
convert a Vissim section number into a Sava route name. eg "4->2". This
requires the each Vissim section number have it's coresponding Sava route name
enteried in it's "name" property.

=item $tt->all_stats();

Prints almost all statistics. Prints "no statistics found" if no data has beed
entered.

=item $tt->vehicle_flow();

Print vehicle flow (veh / hour) on each starting line.

=item $tt->total_number_of_vehicles();

Print total number of vehicles.

=item $tt->number_of_vehicles_per_starting_line();

Print number of vehicles per starting line.

=item $tt->average_travel_time();

Print total average travel time.

=item $tt->average_travel_times_on_all_routes();

Print average travel times, min, max, variance, and standard devation on
each route.

=item $tt->vehicles_stopped_for_red_light();

Print percentage of vehicles that stopped for red light. Requires the usage
of the I<--waitline> option.

=item $tt->vehicle_composistion();

Print the vehicle composition. Useful for SAVA-statistics. Not quite so useful
for Vissim statistics.

=item $tt->vehicle_endline();

Print the routing percentage.

=back

--convert

Convert line numbers present in the Sava input data to Vissim veh inp
numbers. e.g. 1=4 to turn line number 1 into Vissim veh inp 4.
Separate each conversion with a comma. e.g. --convert 1=4,4=32
Obsolete: This functionality has moved to visperl.pl, but it's POD needs
update.

--convert-file

Read sava line to vissim input-/desc/route no from a file. See B<--convert>
Separate each conversion with a new line. Lines beginning with a '#'
-character is considered a comment.
Obsolete: This functionality has moved to visperl.pl, but it's POD needs
update.

=head1 CAVEATS

Still contains obsolete functions convert() and convertfile().
TODO: Not true?

=head1 HISTORY

First version appeared August 2007.

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.com>

==cut
