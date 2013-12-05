#!/usr/bin/perl -w

use strict;
use Getopt::Long;

# Formats passages between lines into data suitable for graph of
# passages over given time periods

# Accepts data from
# * restid.pl using --verbose-export and --nostats (default)
# * vissim rsr-file (using --vissim and --nr)

# Uses a resolution of 1 second

my %i; 	# input source 1
my %i2; # input source 2

my @amount;
my $maxtime = 0;

my %opt;
GetOptions(\%opt, "vissim", "nr=s", "vissim-file=s");

while (<>) {
	chomp;
	readrsr($_, \%i);
}

if(exists($opt{"vissim-file"})) {
	open(INFILE, $opt{"vissim-file"}) or die "Could not open vissim-file\n";
	while (<INFILE>) {
		chomp;
		readrsr($_, \%i2);
	}
}

$maxtime += 2;

if($opt{vissim}) {
	print "Vissim";
}
else {
	print "Sava";
}

if($opt{"vissim-file"}) {
		print ";Vissim";
}
print "\n";

# Print the amount of cars
for (my $sec=0; $sec<$maxtime; $sec++) {
	if (exists($i{$sec})) {
		print "$i{$sec}";
	}
	else {
		print "0";
	}

	if (exists($opt{"vissim-file"})) {
		if (exists($i2{$sec})) {
			print ";$i2{$sec}";
		}
		else {
			print ";0";
		}
	}

	print "\n";
}

# Vissim rsr-file
sub readrsr {
	my $tt; # travel time
	my $line = shift;
	my $input = shift;

	# [completion time];[section];[veh id];[veh type];[travel time];
	$line =~ s/\s//g;   # Remove white-space
	if ($line =~ /\d+\.\d;(.+);.+;.+;(\d+)\.\d;/) {
		unless (exists($opt{nr}) and $opt{nr} ne $1) {
			$tt = $2;
			$input->{$tt}++;
			$maxtime = $tt if ($tt > $maxtime);
		}
	}
}

__END__

=head1 NAME

resformat - prints number of vehicles passing during each second

=head1 SYNOPSIS

B<resformat.pl> [B<--vissim>] [B<--nr>=I<number or route>]
[B<--vissim-file>=I<filename>] [I<filename> ...]

=head1 DESCRIPTION

resformat.pl accepts these types of input

=over 4

=item * restid.pl using --verbose-export and --nostats in restid.pl (default)

The input format is read as:

B<[completion time];[route];[veh id];[vehicle type];[travel time]>

Where B<[completion time]> is the number of seconds from the start of
SAVA-measurement with one decimal precision. B<[route]> is the route that
was used (eg. 1->2 or 4->3). B<[vehicle type]>
is the vehicle type as a string (eg. Car), see the documentation to B<api.pl> for
details. B<[travel time]> is the travel time in seconds with 0 to 2
decimal precision.

A dot is used as decimal separator.

=back

or/and

=over 4

=item * vissim rsr-file (using --vissim or --vissim-file)

The input format is read as:

B<[completion time];[section];[veh id];[veh type];[travel time];>

Where B<[completion time]> is calculated from the start of
VISSIM-simulation with one decimal precision.
B<[section]> is the travel time section. Use the B<--nr> option to use
desired section. B<[veh id]> is vehicle number as an unique vehicle identifier
during simulation. B<[veh type]> is the VISSIM vehicle type identifier
(eg. 100). B<[travel time]> is travel time in seconds with one decimal
precision.

A dot is used as decimal separator.

=back

The program then outputs a list for the number of vehicles passing during
each second, starting with second one.

The output is suitable for creating a chart in e.g. MS Excel. It also adds
the input format type at the beginning of the data as a field so that Excel
uses it as name.

Typically the graph will look like some sort of waveform.

=head1 OPTIONS

resformat.pl accepts the following options:

=over 4

=item B<--vissim>

Input data from standard input or ending filename is of rsr-type from
vissim.

=item B<--nr>=I<number or route>

Only use the given 'travel time section'-number with vissim input. Or, only
use the give route with SAVA-input. Where 'route' is [start line]->[end
line]. eg. "4->3" where 4 is the start line and 3 is the end line.

=item B<--vissim-file>=I<filename>

Read vissim-data from given filename as well. Creates an extra column in
output.

=back

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.com>

=cut
