#!/cygdrive/c/perl/bin/perl -w
#!/usr/bin/perl -w

# Simple queue system for simulations

# CAVEATS
# * Only works with ActiveState perl because the working thread becomes
#   blocked in the system() function with the cygwin version.
# * Exiting vissim incorrectly crashes visperl and doesn't restore vap file
#   it leads to incorrect controller used next time since two sections have
#   same name in vap-file. Se implementation of Ec1Switch.pl for details.
# * spool.pl sometimes crashes when the working thread finishes.
#   "Free to wrong pool xx not xx, <STDIN> line 24 during global destruction"
# * Windows XP is commonly configured for automatic updates and restarts.
#   This may interrupt simulations unexpectedly.
# * Vissim sometimes complain over inability to close .rsr and .rsv files
#   after a simulation run when using a simulation file stored on a network
#   share.
# * The visperl.pl script has a tendency to delete itself. No idea why
# * visperl.pl sometimes fail to start the EC-1 simulator interface due
#   to bugs in the interface. The problem has been traced to large size of
#   the *.vap file used by the EC-1 Vissim interface "vap.dll".
# * Path to all controller project directories are hard-coded
# * The command used to start visperl.pl is hard-coded

use strict;
use threads;
use threads::shared;
use Cwd;
use Ec1SimulatorControl;

# Simple job sheduler
my %joblist : shared;
my $running : shared = undef;
my $pause   : shared = 0;
my $next_job_id = 1;

# Path to controller project directories hard-coded
my $ec1_controller_base_path = "/path/to/controller-project/"; # <<<----- EDIT HERE

my @ec1_controller_paths = (
	"PATH1",  <--- EDIT HERE TOO
	"PATH2",  <---
	"PATH3",  <---
);

# Contains pid of simulator child processes
# (if we started the simulators with this program)
my @ec1s;

# Save current dir (since Ec1SimulatorControl changes it)
my $dir = cwd();

cli();
term_controllers();
exit(0);

# Command line interpreter
sub cli {
	print "> "; $| = 1;
	while(<STDIN>) {
		add_job($_)  if /^a/;
		rm_job($_)   if /^d/;
		pause($_)    if /^p/;
		show_list()  if /^l/;
		show_help()  if /^h/;
		start_all()  if /^s/;
		term_controllers()   if /^k/;
		check_quit() if /^q/;
		print "?\n"  unless /^(a|d|p|l|h|s|k|q)/;
		print "> "; $| = 1;
	}
}

sub start_all {
	start_controllers();
}

sub kill_all {
	my $ec1 = Ec1SimulatorControl->new();
	$ec1->kill()
}

sub check_quit {

	unless (defined($running)) {
		term_controllers();
		exit(0)
	}
	print "There are jobs running! Are you sure you want to quit? (y/n)\n";
	my $ans = <STDIN>;

	if ($ans =~ /^y/) {
		term_controllers();
		exit(0)
	}
}

sub pause {
	if($pause == 0) {
		print "Pause activated\n";
		$pause++;
	} else {
		print "Pause deactivated\n";
		$pause--;
		threads->new(\&run_jobs)->detach if ((!defined($running)) and keys %joblist > 0);
	}
}

sub show_list {
	unless(defined($running)) {
		print "No jobs running\n";
	} else {
		print "Job running: $running\n";
	}

	print "No jobs queued\n" if keys %joblist == 0;
	foreach my $job (sort {$a <=> $b} keys %joblist) {
		print "$job: $joblist{$job}\n";
	}
	if($pause == 1) {
		print "Pause is activated. press 'p' and [Enter] to resume.\n";
	}
}

sub show_help {
	print
		  "a [job-file]  - add job\n".
		  "d [job nr]    - delete job\n".
		  "p             - toggle pause\n".
		  "l             - show queue\n".
		  "h             - show help\n".
		  "s             - start all EC-1 simulators\n".
		  "k             - kill all EC-1 simulators\n".
		  "q             - quit\n";
}

sub add_job {
	my $job = shift;
	if(/a (.*)/) {
		$job = $1;
	} else {
		print "usage: a [job-file]\n";
		return;
	}
	# Change back our dir since Ec1SimulatorControl might have changed it
	chdir $dir;
	stat($job);
	unless (-e _) {
		print "can't find job file: $job\n";
		return;
	}
	print "New job added: $job\n";
	$joblist{$next_job_id} = $job;
	$next_job_id++;

	if (@ec1s == 0) {
		start_all();
	}
	threads->new(\&run_jobs) if ($pause == 0 and !defined($running));
}

sub rm_job {
	my $nr = shift;
	if(/d (.*)/) {
		$nr = $1;
	} else {
		print "usage: d [nr of job]\n";
		return;
	}

	unless(exists($joblist{$nr})) {
		print "job $nr does not exist\n";
		return;
	}
	delete $joblist{$nr};
	print "Removed job: $nr\n";
}

sub run_jobs {
	print "Running jobs...\n";
	print " Number of jobs: ". (keys %joblist) .", pause: $pause\n";
	while ((keys %joblist) > 0 and $pause == 0) {
		my @keys = sort {$a <=> $b} keys %joblist;
		my $key = shift @keys;
		$running = $joblist{$key};
		delete $joblist{$key};

		# Change back our dir since Ec1SimulatorControl might have changed it
		chdir $dir;

		print "Starting visperl with conf: $running...\n";
		my $status = system "C:\\perl\\bin\\perl.exe", "visperl.pl", "-f", $running;
		if ($status == -1) {
			print "failed to execute: $!\n";
		} elsif ($status & 127) {
			printf "child died with signal %d, %s coredump\n",
				($status & 127), ($status & 128) ? 'with' : 'without';
		} else {
			printf "child exited with value %d\n", $status >> 8;
		}
	}
	undef $running;
	print "Jobs finished\n";
}

# Tried and true, but not used anymore
sub start_controllers2 {
	system "C:\\perl\\bin\\perl.exe", "ec1_test.pl";
}

sub start_controllers {
	my $ec1;
	my $pid;
	foreach my $ec1_path (@ec1_controller_paths) {
		$ec1 = Ec1SimulatorControl->new();
		$ec1->set_ec1_project_path($ec1_controller_base_path.$ec1_path);
		$pid = $ec1->start();
		push @ec1s, $pid;
	}
}

sub term_controllers {
	foreach my $ec1 (@ec1s) {
		kill 9, $ec1;
	}
	kill_all();
}


