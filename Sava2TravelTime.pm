
package Sava2TravelTime;
use strict;
use Time::Local;

sub new {
	my $class = shift;
	my $self = {
		starttime	=>	0,
		startline	=>	undef,
		endline		=>	undef,
		waitline	=>	0,
		waiting		=>	0,
		veh			=>	undef,
		traveltimes =>	undef,
		};
	bless ($self, $class);
	return $self;
}

# We must read from files manually, because vehicle identifications are
# not unique across data sets
sub load_sava_files {
	my $self = shift;
	my @files = @_;
	foreach my $filename (@files) {
		open (DATA, $filename) || die("can't open file: $filename - $!");
		while(<DATA>) {
			chomp;
			$self->setline($filename, $_);
		}
		close DATA;
	}
}

# Process text line
# Valid SAVA-input data processed here are on the format
# [time] [veh type] [veh id]   L [line nr]
# Where [time] is on the format HH:MM:SS:MSS (MSS=millisecond)
# [veh type] is a text string describing the type of vehicle
# [veh id] is a unique vehicle identification number
# [line nr] SAVA virtual line
# there may be a variable amount of whitespace before the 'L'
sub setline {
	my $self = shift;
	my $filename = shift;
	my $line = shift;
	# Fetch id and time
	if ($line =~ /^(\d{2}:\d{2}:\d{2}:\d{3}) (\w+) (\d+) +L (\d+)/) {
		my $time = $1;
		my $type = $2;
		my $id = "$filename:$3"; # add uniqueness accoss files
		my $line = $4;

		# Update starttime
		if ($self->timeval($time) < $self->{starttime} or $self->{starttime} == 0) {
			$self->{starttime} = $self->timeval($time);
		}

		if (!exists($self->{veh}{$id}) && $self->isstartline($line)) {
			# Save time and vehicle id to hash if
			# line correspons with startline
			$self->{veh}{$id}{starttime} = $time;
			$self->{veh}{$id}{startline} = $line;
		}
		elsif (exists($self->{waitline}) && $line == $self->{waitline}) {
			# We've found the waiting line
			$self->{waiting}++;
		}
		elsif (exists($self->{veh}{$id}) && $self->isendline($line)) {
			# We've found the end line
			if ($self->{verbose}) {
				print "Veh '$id' of type '$type' waited ";
				print $self->timevalf($time) - $self->timevalf($self->{veh}{$id}{starttime});
				print " seconds\n";
			}

			# Calculate completion time and format it
			my $ctime = $self->timevalf($time) - $self->{starttime};
			$ctime = sprintf("%.1f", $ctime);

			# travel time
			my $tt = $self->timevalf($time) - $self->timevalf($self->{veh}{$id}{starttime});

			# route info
			my $route = $self->{veh}{$id}{startline}."->".$line;

			push @{$self->{traveltimes}}, "$ctime;$route;$id;$type;$tt\n";
			return "$ctime;$route;$id;$type;$tt\n";
		}
	}
	return undef;
}

sub get_travel_time {
	my $self = shift;
	return @{$self->{traveltimes}};
}

sub set_startline {
	my $self = shift;
	my $startlines = shift;
	$self->{startline} = $startlines;
}

sub set_endline {
	my $self = shift;
	my $endlines = shift;
	$self->{endline} = $endlines;
}

sub set_waitline {
	my $self = shift;
	my $waitlines = shift;
	return unless defined($waitlines);
	$self->{waitline} = $waitlines;
}

# Returns 1 if first argument is a endline
sub isendline {
	my $self = shift;
	my $line = shift;
	my @endlines = split(/,/, $self->{endline});
	foreach (@endlines) {
		return 1 if ($line == $_);
	}
	return undef;
}

# Returns 1 if first argument is a startline
sub isstartline {
	my $self = shift;
	my $line = shift;
	my @startlines = split(/,/, $self->{startline});
	foreach (@startlines) {
		return 1 if ($line == $_);
	}
	return undef;
}

# Return time as second
sub timeval {
	my $self = shift;
	my ($hour, $min, $sec, $msec) = split /:/, shift;
	timelocal($sec, $min, $hour,1,1,1);
}

# Return time as second.millisecond
sub timevalf {
	my $self = shift;
	my ($hour, $min, $sec, $msec) = split /:/, shift;
	my $result = timelocal($sec, $min, $hour,1,1,1) .".". $msec;
	Math::BigFloat->new($result);
}

1;

__END__

=head1 NAME

Sava2TravelTime - Convert SAVA-data to travel times

=head1 SYNOPSIS

=over

=item use Sava2TravelTime;

=item $sava = Sava2TravelTime->new();

=item $sava->set_startline(1,2,3);

=item $sava->set_endline(4,5,6);

=item $sava->load_sava_files(@sava_files);

=item @travel_times = $sava->get_travel_time();

=back

=head1 DESCRIPTION

This module provides calculation of travel times from SAVA-data.

=head1 METHODS

=over

=item $sava = Sava2TravelTime->new();

Create a new Sava2TravelTime object.

=item $sava->load_sava_files(@sava_files);

Load one or many Sava-data files. Requires that start/end lines is set first.
Vehicle id is required in order to calculate travel times, but it is usually
not unique across data-files, so this functions adds uniqueness to vehicle
id depending of from which file it's reading.

=item $sava->setline($sava_line);

Set a line of Sava-data manually. In case you don't want to use
load_sava_files(). Remember to add uniqueness to each vehicle id if you
read from different data-files.

=item $sava->get_travel_time();

Returns an array of all travel times calculated.

=item $sava->set_startline(4,5);

Set the Sava line where traffic is starting from. Lines can be both start and
end lines at the same time.

=item $sava->set_endline(1,2,3);

Set the Sava line where traffic measurement is ending. Lines can be both
start and end lines at the same time.

=item $sava->set_waitline(6);

Set the Sava line where traffic is waiting for green light. Not required and
only takes one line number as argument for now. This function is considered
obsolete because it isn't used for anything anymore. It was imported from the
B<restid.pl> program.

=back

=head1 HISTORY

First version appered in August 2007

=head1 AUTHOR

Written by David Otterdahl <david.otterdahl@gmail.org>

==cut
