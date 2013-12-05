
package AxlePassageInterpreter;
use strict;
use Time::Local;

sub new {
	my $class = shift;
	my $self = {
		# Options
#		start				=> undef,
#		end					=> undef,
		tubedistance		=> 3.3,
		maxspeed			=> 70,
		minspeed			=> 5,
		minaxllen			=> 0.5,
		maxaxllen			=> 14.0,
		maxspeedvariation	=> 5,
		bouncereject		=> 0.040,
		careful				=> 34,
#		debug				=> undef,
#		export				=> undef,
		# Variables
		tubebump			=> undef,	# keep track of tube bumps
		axle				=> undef,	# keep track of axels
		numveh				=> 0,		# number of identified vehicles
		numident			=> 0,		# number of identified bumps
		numbump				=> 0,		# total number of bumps
		previoustime		=> 0,		# bounce reject
		careful_counter		=> 0,		# keeps already interpreted bumps
		# Output
		passages			=> undef,
		};
	bless $self, $class;
	return $self;
}

sub setlines {
	my $self = shift;
	my @lines = @_;
	foreach my $line (@lines) {
		chomp($line);
		# Parse time
		if ($line =~ /^\d (\d{2}) \d{6} (\d{2}:\d{2}:\d{5})/) {
			my $channel = $1;
			my $time = $2;
			if ($self->within_timelimits($time)) {
				$self->{numbump}++;
				unless( $self->bouncereject($time, $channel, $self->{previoustime})) {
					$self->{tubebump}{$time} = $channel;
					$self->{previoustime} = $time;
					$self->searchaxles();
				}
			}
		}
	}
}

sub stats {
	my $self = shift;
	# Number of interpreted axles
	my $axlint = $self->{numident} / $self->{numbump} * 100;

	unless (exists($self->{export})) {
		print "Number of vehicles identified: $self->{numveh}\n";
		print "Interpretation rate: ".  sprintf("%.2f", $axlint) ."%\n";
	}
}

# Return the incoming traffic flow
# * only channel 0-1
# * vehicles/hour
# * add missing interpretation rate
sub incoming_flow {
	my $self = shift;

	# Number of vehicles in dir: 0-1, and start/end
	my $incoming;
	my $start = 0;
	my $end = 0;
	foreach my $car (@{$self->{passages}}) {

		if ($car =~ /([0-9]{2}:[0-9]{2}:[0-9]{5})/) {
			my $time = $self->timevalfloat($1);
			$start = $time if($start == 0);
			$end = $time if ($time > $end);
		}
		$incoming++ if ($car =~ /0-1/);
	}

	return undef if ($self->{numbump} == 0);
	my $axlint = $self->{numident} / $self->{numbump}; # interpretation rate
	$incoming /= $axlint;		# Add missing interpretation rate
	$incoming /= (($end - $start) / 3600); # Calculate veh/h
	return sprintf("%d", $incoming);
}

sub searchvehicle {
	my $self = shift;
	# search for earlier axles that can
	# make it correspond to a vehicle
	foreach my $st (sort keys %{$self->{axle}}) {
		foreach my $en (sort keys %{$self->{axle}}) {
			$self->checkvehicle($self->{axle}{$st}, $self->{axle}{$en});
		}
	}
}

sub searchaxles {
	my $self = shift;
	# search for earlier tubebumps that
	# can make it correspond to an axle
	foreach my $firstbump (sort keys %{$self->{tubebump}}) {
		foreach my $secondbump (sort keys %{$self->{tubebump}}) {
			if ($self->checkaxle($firstbump, $secondbump)) {
				$self->searchvehicle();
			}
		}
	}
}

sub checkvehicle {
	my $self = shift;
	my ($axle1, $axle2) = @_;

	return undef unless ($self->isvehicle($axle1, $axle2));

	my $id_axle1 = $axle1->{starttime}.$axle1->{endtime};
	my $id_axle2 = $axle2->{starttime}.$axle2->{endtime};

	my $avgspeed = ($axle1->{speed} + $axle2->{speed}) / 2;

	$axle1->{avgtime} = $self->timeavg($axle1->{starttime}, $axle1->{endtime});
	$axle2->{avgtime} = $self->timeavg($axle2->{starttime}, $axle2->{endtime});

	my $timediff = abs($axle2->{avgtime} - $axle1->{avgtime});
	my $axldistance = $timediff * $avgspeed;

	# Check that the distance between the axels are within
	# acceptable limits
	unless ($axldistance >= $self->{minaxllen} &&
			$axldistance <= $self->{maxaxllen}) {

		if ($self->{careful_counter} == 0) {
			$self->debug("distance between axles are to long or short; deleting first axle\n");
			delete $self->{axle}{$id_axle1};
		}
		return;
	}

	# Check if the speeds between the axels differs more than 5%
	my $diff = abs(($axle1->{speed} / $axle2->{speed}) - 1) * 100;
	if ($diff <= $self->{maxspeedvariation}) {

		$avgspeed = sprintf("%.2f", $avgspeed * 3.6);
		$axldistance = sprintf("%.2f", $axldistance);
		my $dir = $axle2->{direction};
		$self->{numveh}++;

		# get the direction straight
		my $tm = undef;
		if ($self->timediff($axle1->{starttime}, $axle2->{starttime}) > 0) {
			$tm = $axle1->{starttime};
		}
		else {
			$tm = $axle2->{starttime};
		}

		my $vehtype = $self->getveh($axldistance);

		if (exists($self->{export})) {
			# Remove the millisecond part
			$tm =~ s/[0-9]{3}$//g;
#			print "$tm\n";

			# Add identified vehicle to 'passages'-array, formatted and ready
			push @{$self->{passages}}, "$tm\n";
		}
		else {
#			print "$self->{numveh}\t$tm\t$dir\t$vehtype\t$avgspeed";
#			print "\t2\t$axldistance\n";

			# Add identified vehicle to 'passages'-array, formatted and ready
			push @{$self->{passages}}, "$self->{numveh}\t$tm\t$dir\t$vehtype\t$avgspeed\t2\t$axldistance\n";
		}

		# if the bumps still exists, delete them
		delete $self->{tubebump}{$axle1->{starttime}};
		delete $self->{tubebump}{$axle1->{endtime}};
		delete $self->{tubebump}{$axle2->{starttime}};
		delete $self->{tubebump}{$axle2->{endtime}};

		# also delete all axles based upon our bumps
		$self->axledel($axle1->{starttime});
		$self->axledel($axle1->{endtime});
		$self->axledel($axle2->{starttime});
		$self->axledel($axle2->{endtime});

		delete $self->{axle}{$id_axle2};
		delete $self->{axle}{$id_axle1};

		$self->{numident} += 4;
	}

	delete $self->{axle}{$id_axle1} unless ($self->{careful_counter} > 0);
}

# check axles for the basic requirements for being an vehicle
sub isvehicle {
	my $self = shift;
	my ($axle1, $axle2) = @_;

	# incomplete input
	return undef unless (defined($axle1) and defined($axle2));

	# identical axle
	return undef if ($axle1 eq $axle2);

	# incorrect direction
	return undef unless ($axle2->{direction} eq $axle1->{direction});

	return 1;
}

# checks if two bumps is an axle
sub checkaxle {
	my $self = shift;
	my ($starttime, $endtime) = @_;

	return undef unless ($self->isaxle($starttime, $endtime));

	my $dir = $self->direction($starttime, $endtime);
	my $diff = abs($self->timediff($starttime, $endtime));
	my $speed = $self->{tubedistance} / $diff;
	my $speedkmh = $speed * 3.6;

	if ($self->{careful_counter} > 0) {
		if ($self->axleexist($starttime, $endtime)) {
			return undef;
		}
	}

	# Check if speed is within allowed parameters
	if ($speedkmh >= $self->{minspeed} && $speedkmh <= $self->{maxspeed}) {

		# Add as identified axle
		$self->{axle}{$starttime.$endtime}{speed} = $speed;
		$self->{axle}{$starttime.$endtime}{starttime} = $starttime;
		$self->{axle}{$starttime.$endtime}{endtime} = $endtime;
		$self->{axle}{$starttime.$endtime}{direction} = $dir;

		$self->debug("axl: $starttime <-> $endtime"
			." spd:". sprintf("%.2f", $speedkmh)." dir:$dir ");

		# Remove bumps
		unless ($self->{careful_counter} > 0) {
			$self->debug("; del\n", 1);
			delete $self->{tubebump}{$starttime};
			delete $self->{tubebump}{$endtime};
		}
		else {
			$self->debug("; no del\n", 1);
			$self->{careful_counter}--;
		}

		return 1;
	}

	if ($speedkmh > $self->{maxspeed} and $self->{careful_counter} == 0) {
		$self->{careful_counter} = $self->{careful};
		$self->debug("entering careful mode: setting \$careful_counter to ". $self->{careful_counter} ."\n");
		return undef;
	}

	# Clean $tubebumps of old bumps
	if ($speedkmh < $self->{minspeed}) {
		$self->debug("deleting old bump; $starttime speed low - missing bump?\n");
		delete $self->{tubebump}{$starttime};
	}

	return undef;
}

# Delete all axles that uses any of the given start/end time
sub axledel {
	my $self = shift;
	my $time = shift;
	foreach my $ax (keys %{$self->{axle}}) {
		if (($self->{axle}{$ax}{starttime} eq $time) or
			($self->{axle}{$ax}{endtime} eq $time)) {
				delete $self->{axle}{$ax};
		}
	}
}

# check if an axle already exist
# only needed during careful
sub axleexist {
	my $self = shift;
	my ($time1, $time2) = @_;

	foreach my $ax (keys %{$self->{axle}}) {

		if (($self->{axle}{$ax}{starttime} eq $time1 and
		     $self->{axle}{$ax}{endtime}   eq $time2) or
			($self->{axle}{$ax}{starttime} eq $time2 and
			 $self->{axle}{$ax}{endtime}   eq $time1)) {
				return 1;
		}
	}
	return undef;
}

# check bumps for the basic requirements for being an axle
sub isaxle {
	my $self = shift;
	my ($starttime, $endtime) = @_;

	# same time = same bump
	return undef if ($endtime eq $starttime);

	# bump was already removed
	unless (exists($self->{tubebump}{$starttime}) and exists($self->{tubebump}{$endtime})) {
		return undef;
	}

	# bumps are of the same type, can't be an axel
	if ($self->{tubebump}{$starttime} eq $self->{tubebump}{$endtime}) {
		return undef;
	}

	return 1;
}

# check bumps for direction
sub direction {
	my $self = shift;
	my ($starttime, $endtime) = @_;

	my $dir;
	if ($self->{tubebump}{$starttime} eq "00") {
		if ($self->timediff($starttime, $endtime) > 0) {
			return "0-1";
		}
		else {
			return "1-0";
		}
	} else {
		if ($self->timediff($starttime, $endtime) > 0) {
			return "1-0";
		} else {
			return "0-1";
		}
	}
}

# returns float time from format HH:MM:SSMSS incl trailing milliseconds
sub timevalfloat {
	my $self = shift;
	my ($hour, $min, $sec) = split /:/, shift;
	my $msec;
	$sec =~ /(\d{2})(\d{3})/;
	$sec = $1;
	$msec = $2;
	my $result = timelocal($sec, $min, $hour, 1, 1, 1) . ".". $msec;
}

# returns time difference in seconds, using HH:MM:SSMSS format
sub timediff {
	my $self = shift;
	my ($start, $end) = @_;
	return $self->timevalfloat($end) - $self->timevalfloat($start);
}

# returns average time
sub timeavg {
	my $self = shift;
	my ($start, $end) = @_;
	return ($self->timevalfloat($end) + $self->timevalfloat($start)) / 2;
}

# returns 1 if bouncereject
sub bouncereject {
	my $self = shift;
	my ($time, $channel, $ptime) = @_;
	return undef unless exists($self->{tubebump}{$ptime});
	my $pchannel = $self->{tubebump}{$ptime};
	return undef unless ($channel eq $pchannel);
	if (abs($self->timediff($time, $ptime)) < $self->{bouncereject}) {
		$self->debug("bouncereject! $time $channel <-> $ptime $pchannel\t".
		abs($self->timediff($time, $ptime)) ."\n");
		return 1;
	}
	return undef;
}

# get vehicle type based on distance between axles
sub getveh {
	my $self = shift;
	my $axllen = shift;
	if    ($axllen <= 1.2) { return "Cycle\t" }
	elsif ($axllen > 1.2 and $axllen <= 2.0)  { return "MC\t" }
	elsif ($axllen > 2.0 and $axllen <= 3.5)  { return "Car\t" }
	elsif ($axllen > 3.5 and $axllen <= 4.0)  { return "Van/MPV\t" }
	elsif ($axllen > 4.0 and $axllen <= 14.0) { return "Lorry/Bus" }
}

# print debug infomation
sub debug {
	my $self = shift;
	return unless exists($self->{debug});
	my $txt = shift;
	unless (defined(shift)) { push @{$self->{passages}}, "[debug] $txt" }
}

# Check if we're within time constraints
sub within_timelimits {
	my $self = shift;
	my $current_time = shift;
	if (exists($self->{start})) {
		$self->{start} =~ s/$/:00000/;  # Add second.millisecond portion
		return undef if ($self->timevalfloat($self->{start}) >
			$self->timevalfloat($current_time));
	}
	if (exists($self->{end})) {
		$self->{end} =~ s/$/:00000/;   # Add second.millisecond portion
		return undef if ($self->timevalfloat($self->{end}) <
			$self->timevalfloat($current_time));
	}
	return 1;
}
1;

