

package Ec1SimulatorControl;
use strict;
use Carp;

# Used for finding windows and pressing keys
use Win32::GuiTest qw(FindWindowLike SetForegroundWindow SendKeys
	GetWindowText SetActiveWindow GetForegroundWindow);

# Used for forcing window to foreground
use Win32::GUI();

# Used for kill process
use Win32::PerfLib;
use Win32::Process;
use Win32::Process::Info;

# Used for updating Simulator.ini
use Tie::File;

sub new {
	my $class = shift;
	my $self = {
		CHILD_PID				=> undef,
		EC1_simulator_path		=> "C:\\EC1Tools\\Simulator",
		EC1_simulator_exe		=> "EC1Simulator.exe",
		EC1_simulator_license   => "\\\\C:\\EC1Tools\\Data\\Packages\\2\\",
		EC1_simulator_settings	=> "[EXTSIM][00]44",
		EC1_project_path		=> undef,
	};
	bless $self, $class;
	return $self;
}

# Set EC1 project path
sub set_ec1_project_path {
	my $self = shift;
	$self->{EC1_project_path} = shift;
}

# Start simulator by forking and exec()
sub start {
	my $self = shift;

	croak("EC-1 project path not set!") unless defined $self->{EC1_project_path};

	my $arguments = $self->{"EC1_project_path"}.
		$self->{"EC1_simulator_license"}.
		$self->{"EC1_simulator_settings"};
	my @args = split / /, $arguments;
	my $exe = $self->{"EC1_simulator_path"}."\\".$self->{"EC1_simulator_exe"};

	chdir $self->{"EC1_simulator_path"};

	# Fork process, because we can't wait
	if (!defined($self->{CHILD_PID} = fork())) {
		die "cannot fork: $!";
	} elsif ($self->{CHILD_PID}) {
		# parent
		sleep 1;
		$self->silence_msgbox();
		return $self->{CHILD_PID};
	} else {
		# child
		exec( { $exe } @args ) || die "can't open simulator: $!";
	}
}

# Kill simulator
sub kill {
	my $self = shift;

	if (defined($self->{CHILD_PID})) {
		kill 9, $self->{CHILD_PID};
	}

	my $pid;
	while($pid=$self->getpid('EC1Simulator')) {
		Win32::Process::KillProcess($pid, 0);
	}
}

# The EC-1 simulator reads settings from Simulator.ini
# in the simulator project directory
sub check_simulator_ini {
	my $self = shift;
	croak("EC-1 project path not set!") unless defined $self->{EC1_project_path};
	my $elcpath = $self->{EC1_project_path} . "\\elc.dat";
	my $simpath = $self->{EC1_project_path} . "\\Simulator.ini";
	my $xppath  = $self->{EC1_project_path} . "\\XP.dat";
	croak("Cannot find elc.dat!\n") unless stat $elcpath;
	croak("Cannot find Simulator.ini!") unless stat $simpath;
	croak("Cannot find XP.dat!") unless stat $xppath;

	my @lines;
	tie @lines, 'Tie::File', $simpath || die("can't open simulator.ini: $!\n");
	for (@lines) {
		if (/EXTSIM=(.*)/) {
			print "Simulator: Listening on port $1\n";
		}
		if (/SignalGroupMsg=(.*)/) {
			print "Simulator: Update rate: $1 times/sec\n";
		}
		if (/SgMsgOnChange=(.*)/) {
			print "Simulator: Update on change: $1\n";
			croak("'Update on change' not set to 1!\n") unless $1 eq 1;
		}
	}
	untie @lines;
}

# Silence the License msg-box
sub silence_msgbox {
	my $self = shift;

	until ($self->silence_msgbox_loop()) {
		sleep 5;
	}
}

sub silence_msgbox_loop {
	my $self = shift;
	my @windows = FindWindowLike(0, "EC1Simulator", "");
	for (@windows) {
		force_foreground_window($_);
		return 1;
	}
}

# Taken http://vb.mvps.org/articles/ap199902.pdf
# and adapted for perl
# From the page:
# "Under newer Windows versions, Microsoft has disabled the
# SetForegroundWindow API call in all cases except when the
# calling application currently maintains the foreground.
# This routine forces the issue by attaching itself to the
# foreground thread, faking out the operating system.
sub force_foreground_window {
	my $hwnd = shift;

	# Nothing to do if already in foreground
	if ($hwnd == GetForegroundWindow()) {
		SendKeys("{SPACEBAR}");
		return 1;
	}

	# First need to get the thread responsible for
	# the foreground window, then the thread running
	# the passed window.
	my $thread1 = Win32::GUI::GetWindowThreadProcessId(GetForegroundWindow());
	my $thread2 = Win32::GUI::GetWindowThreadProcessId($hwnd);

	# By sharing input state, thread share their
	# concept of the active window.
	my $nret;
	if ($thread1 ne $thread2) {
		# The following functions calls (with two SendKeys() calls)
		# seems to work best
		Win32::GUI::AttachThreadInput($thread1, $thread2, 1);
		Win32::GUI::SetActiveWindow($hwnd);
		SendKeys("{SPACEBAR}");
		$nret = SetForegroundWindow($hwnd);
		Win32::GUI::AttachThreadInput($thread1, $thread2, 0);
		SendKeys("{SPACEBAR}");
	} else {
		$nret = SetForegroundWindow($hwnd);
		SendKeys("{SPACEBAR}");
	}
	return $nret;
}

sub getpid {
	my $self = shift;
    my $process = shift;

    my $server = $ENV{COMPUTERNAME};
    my $pid;

	my %counter;

    Win32::PerfLib::GetCounterNames($server, \%counter);
    my %r_counter = map { $counter{$_} => $_ } keys %counter;
    my $process_obj = $r_counter{Process};
    my $process_id = $r_counter{'ID Process'};
    my $perflib = new Win32::PerfLib($server) || return 0;
    my $proc_ref = {};
    $perflib->GetObjectList($process_obj, $proc_ref);
    $perflib->Close();
    my $instance_ref = $proc_ref->{Objects}->{$process_obj}->{Instances};
    foreach my $p (sort keys %{$instance_ref}){
        my $counter_ref = $instance_ref->{$p}->{Counters};
        foreach my $i (keys %{$counter_ref}){
            if($counter_ref->{$i}->{CounterNameTitleIndex} ==
               $process_id && $instance_ref->{$p}->{Name} eq $process){
                $pid = $counter_ref->{$i}->{Counter};
                last;
            }
        }
    }

    #try again using a different approach WMI
    unless ($pid){
        if (my $pi = Win32::Process::Info->new($server)){
            my $processes = $pi->GetProcInfo();
            my $number = @$processes;
            foreach (@$processes){
                if ($_->{Name} =~ /$process/i){
                    $pid = $_->{ProcessId};
                }
            }
        }
    }
}

1;

__END__

=head1 NAME

EC1SimulatorControl - Start an EC-1 Simulator for usage in Vissim

=head1 SYNOPSIS

=over 4

=item use Ec1SimulatorControl;

=item $ec1 = Ec1SimulatorContol->new();

=item $ec1->set_ec1_project_path($path);

=item $ec1->start();

=item ...

=item $ec1->kill();

=back

=head1 DESCRIPTION

Starts an EC-1 simulator (with the EXTSIM extension). The most common scenario
is to use it in combination with Vissim.

=head2 Requirements for usage with Vissim

=over 4

=item * Vissim settings

Use controller type "VAP" with program type "Vap.dll" (EC-1/Vissim interface),
Interstages file: "dummy.pua" (empty file) and Logic file: Vap-file.

=item * Vap-file in the Vissim project path with matching settings

The filename is written on the form I<nr>.vap where I<nr> usually is the
controller number.
The Vap-filename is defined in the Vissim project file as "Logic File".
The Vap-file defines one or many traffic controllers. Important settings
include the title e.g. "[44]" which must match controller number in Vissim.
"Port" which defines IP-number and port-number of the Simulator. "NUM*", "SG",
"DET", "PBID", "PB" and so on.

=item * XP.dat, elc.dat and Simulator.ini with matching settings

The XP.dat, elc.dat and Simulator.ini can all be found under the EC-1 project
path. elc.dat defines the programming. Simulator.ini defines
which TCP port the simulator should listen to (EXTSIM). This must be the
same number as defined in the Vap-file. Also make sure
that SignalGroupMsg=10 (number of updates per second) and SgMsgOnChange=1
(only update on change). The last one is especially important since it may not
be enabled by default.

=back

=head2 Basic function

=over 4

=item 1, Set the ec1-project path

=item 2, Start the simulator

=item 3, Silence the msgbox

=item 4, (run the simulation)

=item 5, Kill the simulator process

=back

=head1 METHODS

=over 8

=item $ec1 = Ec1SimulatorControl->new();

Create a new Ec1SimulatorControl object

=item $ec1->set_ec1_project_path($path);

Set the EC-1 project path

=item $ec1->start();

Start the simulator

=item $ec1->kill();

Stop and kill the simulator processes. Warning! This kill ALL simulators that happens to be running.

=item $ec1->check_simulator_ini();

Checks that all requried simulator files are avalible (elc.dat, XP.dat,
Simulator.ini).
Prints some simulator settings such as port number. Will croak unless
all files exists. Also croaks unless "Update on change" is 1.
Recommended to use before start.

=back

=head1 CAVEATS

=over 8

=item * Requires Win32::GuiTest for access to several Windows API functions.

But Win32::GuiTest is seldomly installed by default.

=item * Does not work properly with cygwin perl.

Due to that cygwin perl's system() function doesn't seem to support
"argument 0-handling".
The EC-1 Simulator must be "fooled" about the first argument when starting it,
and starting perl from cygwin doesn't seem to make system() or exec() work
that way. Maybe possible to solve using a WinAPI function?

=item * SetForegroundWindow fails under many circumstances

makes it unreliable.
Could possibly be solved by additional Windows API calls. Example code
exists for VB on http://vb.mvps.org/articles/ap199902.pdf. Otherwise
we could make a small vb program containing the hack that we call from
here.
   We may need:
	GetWindowThreadProcessId()  Win32::GUI
	AttachThreadInput()		Win32::GUI
	GetForegroundWindow()	Win32::GUI
	SetForegroundWindow()   Win32::GUI, Win32::GuiTest
	IsIconic()				Win32::GUI
	ShowWindow()			Win32::GUI (can be attached) ??
   Intressting URLs:
   * http://www.perlmonks.org/?node_id=422068
   * http://discuss.fogcreek.com/joelonsoftware2/default.asp?cmd=show&ixPost=43806&ixReplies=21
   * http://fox.wikis.com/wc.dll?Wiki~ForceWindowtoFrontNotJustBlink~VFP
   * http://cubicspot.blogspot.com/2007/03/setforegroundwindow.html
   * http://vb.mvps.org/samples/project.asp?id=ForceFore
   * http://vb.mvps.org/articles/ap199902.pdf
   * http://www.delphi3000.com/articles/article_1775.asp?SK=
   * http://support.microsoft.com/kb/97925
   * http://www.codeguru.com/forum/showthread.php?threadid=406134
   * http://search.cpan.org/dist/Win32-GuiTest/GuiTest.pm
   Update: 2007-10-06
      Code is inserted, it works as good as it can be under normal conditions.
      Windows *can't* focus and send key events when desktop is locked
      (like after a remote desktop session)
      Instead: The spooler must start *all* controllers at the beginning

=item * 'update on change' Ec1-setting should be enabled. but isn't when using
   this module?

without it, makes signal changing too slow. This propery is probably read
from the "SgMsgOnChange" setting in Simulator.ini which can be found in
the EC1_project path. Perhaps we should set automatically or by an simple
function?  We should also check the "EXTSIM" setting.

=back

=head1 HISTORY

The first version appered in September 2007.

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.org>

=cut

