#!/bin/perl -w

use strict;
use Getopt::Long;

my %t;
my $statmin = 0;
my $interval = 15;

GetOptions("interval=i" => \$interval);

while (<>) {
	if (/(\d{2}):(\d{2}):(\d{2})/) {
		my $hour = $1;
		my $min = $2;
		my $sec = $3;

		if ( !($min % $interval) ) {
			$statmin = $min;
		}

		$t{$hour.":".$statmin}++;
	}
}

foreach my $time (sort keys %t) {
	print "$time;$t{$time}\n";
}

__END__

=head1 NAME

apiformat - axle passage formatter

=head1 SYNOPSIS

B<apiformat.pl> [B<--interval>=I<minutes>]

=head1 DESCRIPTION

B<apiformat.pl> formats the output from B<api.pl> into vehicles by given
time period.

The input format is [hour]:[minute]:[second]. Use B<api.pl --export> to get
this format.

The output format is [hour:minute];[num of vehicles during this time period].

=head1 OPTIONS

=over 4

=item B<--interval>=I<minutes>

Reporting interval

=back

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.com>

=cut
