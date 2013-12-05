#!/usr/bin/perl -w

use strict;
use Time::Local;
use Getopt::Long;
use AxlePassageInterpreter;

my $api = AxlePassageInterpreter->new();
GetOptions(\%{$api}, "start=s", "end=s", "tubedistance=f", "maxspeed=i",
	"minspeed=i", "minaxllen=f", "maxaxllen=f",
	"maxspeedvariation=i", "bouncereject=f",
	"careful=i", "debug", "export");
$api->setlines(<>);
print @{$api->{passages}};
$api->stats();
print "Adjusted incoming veh flow (veh/h): ";
print $api->incoming_flow();

__END__

=head1 NAME

api - axle passage interpreter

=head1 SYNOPSIS

B<api.pl> [B<--start>=I<HH:MM>] [B<--end>=I<HH:MM>]
[B<--tubedistance>=I<meters>] [B<--maxspeed>=I<km/h>]
[B<--minspeed>=I<km/h>] [B<--minaxllen>=I<meters>]
[B<--maxaxllen>=I<meters>] [B<--maxspeedvariation>=I<percent>]
[B<--bouncereject>=I<seconds>] [B<--careful>=I<integer>] [B<--debug>]
[B<--export>] [I<filename>..]

=head1 DESCRIPTION

B<api.pl> is a axle passage interpreter program designed to be used to
analyse traffic data from pneumatic tubes and convert to axle passages.

=head1 OPTIONS

=over 4

=item B<--start>=I<HH:MM>

Optional. Start time for result interpretation.

=item B<--end>=I<HH:MM>

Optional. End time for result interpretation.

=item B<--tubedistance>=I<meters> (floating point)

Optional. This value represents the distance between the two rubber tubes.
Default is 3.3 meters.

=item B<--maxspeed>=I<km/h> (integer)

Optional. Maximum speed allowed for interpreation. Default is 70 km/h.

=item B<--minspeed>=I<km/h> (integer)

Optional. Minimum speed allowed for interpreation. Default is 5 km/h.

=item B<--minaxllen>=I<meters> (floating point)

Optional. Mimium distance between axles of a vehicle. Default is 0.5 meters.

=item B<--maxaxllen>=I<meters> (floating point)

Optional. Maximum distance between axles of a vehicle. Default is 14 meters.

=item B<--maxspeedvariation>=I<percent> (integer)

Optional. Maximum speed variation between axles of a vehicle. Default is
5 %. Needed in order to figure out if two axles belong to the same
vehicle.

=item B<--bouncereject>=I<seconds> (floating point)

Optional. Rejects pulses that are too close to each other time-wise.
Sometimes caused by heavy vehicles that makes the rubber tube bounce.
Default value is 0.040 seconds.

=item B<--careful>=I<integer>

Optional. Fine tunes the internal logic. Controls how many axles we
calcuate from pulses in hard places before we decide to delete
impossible axles. Default is 34, but values lower that 34 is known to
give almost as good results by using significantly less CPU.
Higher values than 34 does not necessarily give better results.

=item B<--export>

Optional. Enable export output. This will just print the passing time of
each vehicle in the format: [HH]:[MM]:[SS]. This format is required for
B<apiformat.pl>.

=item B<--debug>

Optional. Enables debug output. Makes api.pl print debug information as
well as normal output. It will make it print each detected axle, when it
enters 'careful mode' and when it gives up trying to combine pulses into
axle or axles into vehicles. Debug info is printed to STDOUT, but is easily
grepable since each debug line starts with the text '[debug]'.

=back

=head1 CAVEATS

=head2 Noticed problems

=over 8

=item * Heavy vehicles sometimes causes bounces. We're using bounce
reject set to 40 milliseconds by default

=item * Light MC's sometimes doesn't cause enough pressure for pulses.
Incomplete pulse patterns will be ignored

=back

Two vehicles passing the tubes in each direction at almost the same
time are hard to deal with. This program uses brute force to combine all
pulses to axles in such situations.

=head2 Limitations

=over 4

=item * No more that 2 axles

This program doesn't support vehicles with more that two axles.
This however doesn't seem to affect the interpreation accuracy much.

=item * Only channel 01 and 00

We don't support any other channels in TMS Logger data than 01 and 00.

=item * No Time-Pass Variation or Car-Follow Critera

Brute force is used when needed.

=item * No fine tuning of vehicle definitions

There is no option to fine tune the vehicle definitions. This is
seldomly needed anyway.

=back

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.com>

=cut
