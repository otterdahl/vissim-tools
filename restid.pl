#!/usr/bin/perl -w

use strict;
use Time::Local;
use Math::BigFloat;
use Getopt::Long;
use TravelTimeStats;
use Sava2TravelTime;

my %veh;		# vehicle start time
my %opt;		# options
my $waiting;	# vehicles stopping for red light
my $starttime=0;# start time

GetOptions(\%opt, "startline=s", "waitline=i", "endline=s", "verbose",
	"verbose-export", "nostats", "vissim", "convert=s", "convert-file=s");

unless(exists($opt{startline}) and exists($opt{endline})) {
	print "syntax: restid.pl --startline y --waitline z --endline x\n";
	print "        --verbose --verbose-export --nostats --vissim\n";
	print "        --convert --convert-file [filename]\n";
	exit(1);
}

my $stat = TravelTimeStats->new();
my $sava = Sava2TravelTime->new();

$sava->set_startline($opt{startline});
$sava->set_waitline($opt{waitline});
$sava->set_endline($opt{endline});


$sava->load_sava_files(@ARGV);

# Take all travel times and put them in statistics-module
foreach my $tt ($sava->get_travel_time()) {
	$stat->setdata($tt);
	if ($opt{"verbose-export"}) {
		print $tt;
	}
}

# Don't print stats if --nostats is defined
exit(0) if exists($opt{nostats});

if (exists($opt{vissim})) {
	$stat->set_convert($opt{convert});
	$stat->convertfile($opt{"convert-file"});
	#TODO: statsvissim() has been removed from TravelTimeStats...
	#--vissim is depreacted
	print $stat->statsvissim();
}
else {
	$stat->all_stats();
}

__END__

=head1 NAME

restid - prints statistics from SAVA output

=head1 SYNOPSIS

B<restid.pl> [B<--startline>=I<startline1>[I<,startline2..>]]
[B<--waitline>=I<waitline>]
[B<--endline>=I<endline1>[I<,endline2..>]] [B<--verbose>]
[B<--verbose-export>] [B<--nostats>] [B<--vissim>] [B<--convert>]
[B<--convert-file>=I<filename>]
[I<filename>]...

=head1 DESCRIPTION

restid.pl reads the output from SAVA program and prints
statistics about travel time.

Valid SAVA-input data processed here are on the format

B<[time] [veh type] [veh id]   L [line nr]>

Where B<[time]> is on the format HH:MM:SS:MSS (MSS=millisecond).
B<[veh type]> is a text string describing the type of vehicle.
B<[veh id]> is a unique vehicle identification number.
B<[line nr]> SAVA virtual line.
There may be a variable amount of whitespace before the 'L'.

=head1 OPTIONS

restid.pl accepts the following options:

=over 8

=item B<--startline>=I<startline>

Required. The number(s) of the starting line(s) which the vehicle passes
or might pass. If you enter several numbers, separate them with a comma (",").

=item B<--waitline>=I<waitline>

Optional. The number of the waiting/stop line. Used if the vehicle needed
to stop due to red light.

=item B<--endline>=I<endline>

Required. The number(s) of the ending line(s) which the vehicles passes
or might pass. If you enter several numbers, separate them with a comma (",").

=item B<--verbose>

Display each travel time calculated (like Vissim's 'raw' option).

=item B<--verbose-export>

Like --verbose, excepts outputs a semicolon (";") separated list, suitable
for export. The decimal separator used is a dot (".").
Format:

B<[completion time];[route];[veh id];[vehicle type];[travel time]>

Where B<[completion time]> is the number of seconds from the start of the
SAVA-measurement.

=item B<--nostats>

No statistics will be printed (only makes sense if used in combination with
--verbose or --verbose-export).

=item B<--vissim>

Output traffic volume and routing relative flow in a format
compatible with B<visperl.pl>
Deprecated. visperl.pl contains neccecary logic itself.

=item B<--convert>

Convert line numbers present in the Sava input data to Vissim veh inp
numbers. e.g. 1=4 to turn line number 1 into Vissim veh inp 4.
Separate each conversion with a comma. e.g. --convert 1=4,4=32
Note: This option only works in combination with the B<--vissim> option.

=item B<--convert-file>=I<filename>

Read sava line to vissim input-/desc/route no from a file. See B<--convert>
Separate each conversion with a new line. Lines beginning with a '#'
-character is considered a comment.
Note: This option only works in combination with the B<--vissim> option.

=back

=head1 CAVEATS

B<--waitline> only accepts one number.

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.com>

=cut
