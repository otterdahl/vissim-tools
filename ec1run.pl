#!/cygdrive/c/perl/bin/perl -w

use strict;
use Ec1SimulatorControl;

unless($#ARGV >= 0) {
	die("usage: ./ec1run.pl [EC-1 Project path]\n");
}
my $path = $ARGV[0];
my $ec1 = Ec1SimulatorControl->new();
$ec1->set_ec1_project_path($path);
$ec1->check_simulator_ini();
$ec1->start();
cli();

sub cli {
	print "Press q and <ENTER> to quit\n";
	print "> "; $| = 1;
	while(<STDIN>) {
		quit() if /^q/;
		print "> "; $| = 1;
	}
}

sub quit {
	$ec1->kill();
	exit(0);
}
