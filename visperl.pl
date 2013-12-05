#!/cygdrive/c/perl/bin/perl -w
#!/usr/bin/perl -w

use strict;
use Win32::OLE;
use Getopt::Long;
use File::Copy;
use Cwd;
use Net::SMTP;
use TravelTimeStats;
use Sava2TravelTime;
use AxlePassageInterpreter;
use Ec1SimulatorControl;
use Ec1Switch;

my $VI;
my $org_cwd = cwd();
my %opt = (
	iterations => 1,
);
my $rsz;
my $rsr;

my @sava_files;

GetOptions(\%opt, "net=s", "path=s", "rsz=s", "rsr=s", "period=i",
	"iterations=i", "increase_all_volume=i", "increase_vehinp_volume=s",
	"input=s", "route=s", "nullify-unused",
	"stdopt", "compile", "stat", "verbose", "sava-startline=s",
	"sava-endline=s", "sava-convert-file=s", "route-type-file=s", "reality",
	"api-start=s", "api-end=s", "api-control-file=s", "ec1-controller=s",
	"fill-unused", "mail-smtp=s", "mail-from-addr=s", "mail-from-name=s",
	"mail-subject=s", "mail-to=s", "config|f=s", "use-own-simulator-control");

# Set options using standard input
set_options_from_stdin() if(exists($opt{stdopt}));

# Set options using config file
set_options_from_config_file() if(exists($opt{config}));

unless(exists($opt{net})) {
	print "Syntax:\n";
	print "--path [vissim project path] (optional)\n";
	print "--net [inp-file] (required)\n";
	print "--rsz [compiled travel-time-file] (optional)\n";
	print "--rsr [raw travel-time-file] (optional)\n";
	print "--period [simulation duration] (optional)\n";
	print "--iterations [no of iterations] (optional)\n";
	print "--increase_all_volume [volume increase %] (optional)\n";
	print "--increase_vehinp_volume [vehinp1,vehinp2=%:vehinp3=%] (optional)\n";
	print "--input [veh inp=volume,..] (optional)\n";
	print "--route [[routing dec]:[route]=[relative traffic flow],..] (optional)\n";
	print "--nullify-unused (optional)\n";
	print "--stdopt (optional)\n";
	print "--compile (optional)\n";
	print "--stat (optional)\n";
	print "--verbose (optional)\n";
	print "--sava-startline (optional)\n";
	print "--sava-endline (optional)\n";
	print "--sava-convert-file (optional)\n";
	print "--route-type-file (optional)\n";
	print "--realtity (optional)\n";
	print "--api-control-file (optional)\n";
	print "--ec1-controller (optional)\n";
	print "--fill-unused (optional)\n";
	print "--mail-smtp (optional)\n";
	print "--mail-from-addr (optional)\n";
	print "--mail-from-name (optional)\n";
	print "--mail-subject (optional)\n";
	print "--mail-to (optional)\n";
	print "--config, -f (optional)\n";
	exit(1);
}

# Open log file and set it for output
my $log;
open(LOG, '>', \$log) or die "Could not open logfile\n";
select(LOG);

# Set incoming flow and routing from SAVA
sava_import() if (exists($opt{"sava-startline"}));

# Set incoming flow from API
api_import() if (exists($opt{"api-control-file"}));

# Make sure we've got a valid path
# combine path and net if needed
get_full_path();

# Start EC-1 simulator
my $ec1;
my $ec1switch;
if (exists($opt{"use-own-simulator-control"})) {
	$ec1 = Ec1SimulatorControl->new();
	if (exists($opt{"ec1-controller"})) {
		verbose("Setting ec1-controller");
		$ec1->set_ec1_project_path($opt{"ec1-controller"});
	} else {
		warn "Warning! use-own-simulator-control, but not ec1-controller\n";
	}
	$ec1->start();
	#sleep 60; # Wait until simultor calms down
} else {
	# Use correct EC-1 simulator
	$ec1switch = Ec1Switch->new();
	if (exists($opt{"ec1-switch"})) {
		verbose("Switching ec1-controller\n");
		$ec1switch->set_vap_file($opt{path} ."\\". $opt{"ec1-vap"});
		$ec1switch->set_vap_file_backup($opt{path} ."\\". $opt{"ec1-vap"}.
				".backup");
		$ec1switch->backup_vap_file();
		$ec1switch->rename_section(split(/=/, $opt{"ec1-switch"}));
	}
}

# Run simulation
verbose("Open Vissim proj: ". $opt{fullpath} ."\n");
$VI = Win32::OLE->GetActiveObject('VISSIM.vissim')
	|| Win32::OLE->new("VISSIM.vissim")
	|| die "Could not start Vissim\n";
$VI->LoadNet($opt{fullpath}, 0);

$VI->Evaluation->SetProperty('AttValue', "TRAVELTIME", 1);
$VI->Evaluation->TravelTimeEvaluation->SetProperty('AttValue', "FILE", 1);
$VI->Evaluation->TravelTimeEvaluation->SetProperty('AttValue', "COMPILED", 1);
$VI->Evaluation->TravelTimeEvaluation->SetProperty('AttValue', "RAW", 1);

# Set period if it is defined
# Otherwise, read it instead
if(exists($opt{period})) {
	set_simulation_period();
}
else {
	get_simulation_period();
}

#TODO: Reenable --input and --route
set_traffic_volumes(); #if(exists($opt{input}));
set_routing_flows(); #if(exists($opt{route}));

set_volume_percentage() if(exists($opt{increase_all_volume}));
set_vehinp_volume_percentage() if(exists($opt{increase_vehinp_volume}));

# Total travel time statistics
my $tt = TravelTimeStats->new();
chdir $org_cwd;
$tt->route_type_file($opt{"route-type-file"}) if(exists($opt{"route-type-file"}));
get_full_path(); #change back path

for(my $i=0; $i<$opt{iterations}; $i++) {
	set_random_seed();
	verbose(sprintf("Running iteration no: %i\n", $i+1));
	$VI->Simulation->RunContinuous;

	rename_results();
	print_compiled() if(exists($opt{compile}));
	print_travel_time_stats($i+1) if(exists($opt{stat}));
	add_travel_time($tt);
}

# Total travel time statistics
print_total_time_stats($tt);

$VI->Exit;

# Close EC-1 Simulator
if (exists($opt{"use-own-simulator-control"})) {
	$ec1->kill();
} else {
	$ec1switch->restore_vap_file();
}

compare_with_reality() if (exists($opt{reality}));

# Close log-file
close LOG;

# Print log to STDOUT
select(STDOUT);
print $log;

send_email($log) if (exists($opt{"mail-smtp"}));

# Set options, vehicle input and routing from
# Sava-traveltime-stats-..
sub sava_import {
	if (exists($opt{"sava-control-file"})) {
		set_sava_files_from_config_file();
	}
	else {
		set_sava_files_from_argv(@ARGV);
	}
	my $sava = Sava2TravelTime->new();
	my $stat = TravelTimeStats->new();
	$sava->set_startline($opt{"sava-startline"});
	$sava->set_endline($opt{"sava-endline"});
	$sava->load_sava_files(@sava_files);

	$stat->set_all_data($sava->get_travel_time());
	$stat->set_convertfile($opt{"sava-convert-file"});

#	Deprecated: old clumsy method of reading input/route
#	set_options(split(/\n/, $stat->statsvissim()));

	# Test new elegant vehicle input and route info
	# we transfer hash refs
	$opt{vehicleinput} = $stat->stats_input();
	$opt{vehicleroutes} = $stat->stats_route();
}

# Import vehicle inputs from API
sub api_import {
	open APICONTROL, $opt{"api-control-file"};
	while (<APICONTROL>) {
		unless (/#/) {
			my ($veh_nr, $apif) = split ";";
			my $api = AxlePassageInterpreter->new();
			$api->{start} = $opt{"api-start"} if exists($opt{"api-start"});
			$api->{end} = $opt{"api-end"} if exists($opt{"api-end"});
			open API, $apif;
			$api->setlines(<API>);
			close API;

			# if we're replacing a sava value, save the replaced
			if (exists($opt{vehicleinput}{$veh_nr})) {
				$opt{replaced_input}{$veh_nr} = $opt{vehicleinput}{$veh_nr};
			}

			$opt{vehicleinput}{$veh_nr} = $api->incoming_flow();
		}
	}
	close APICONTROL;
}

# Compare with reality
sub compare_with_reality {
	chdir $org_cwd;		# Change back to original working dir, so can find
						# the sava-files
	my $stat = TravelTimeStats->new();
	my $sava = Sava2TravelTime->new();

	$sava->set_startline($opt{"sava-startline"});
	$sava->set_endline($opt{"sava-endline"});
	$sava->load_sava_files(@sava_files);
	$stat->route_type_file($opt{"route-type-file"}) if(exists($opt{"route-type-file"}));
	$stat->set_all_data($sava->get_travel_time());
	my $table = "Video observation (SAVA): Travel times";
	$stat->average_travel_times_on_all_routes_table($table);
}

# Set options using standard input
sub set_options_from_stdin {
	while (<STDIN>) {
		chomp;
		s/\"//g;
		unless ((/#/) or (/^$/)) {
			my @type = split / /, $_, 2;
			$opt{$type[0]} = $type[1];
		}
	}
}

# Set options using config file
sub set_options_from_config_file {
	open CONF, $opt{config};
	while (<CONF>) {
		chomp;
		s/\"//g;
		unless ((/#/) or (/^$/)) {
			my @type = split / /, $_, 2;
			$opt{$type[0]} = $type[1];
		}
	}
	close CONF;
}

# Set options using @array
sub set_options {
	my @opt = @_;
	foreach my $o (@opt){
		my @type = split /=/, $o, 2;
		$opt{$type[0]} = $type[1];
	}
}

# Set SAVA files from files on command line
sub set_sava_files_from_argv {
	@sava_files = @_;
}

# Set SAVA files from config-file
sub set_sava_files_from_config_file {
	open SAVACONTROL, $opt{"sava-control-file"};
	while (<SAVACONTROL>) {
		chomp;
		unless (/#/) {
			push @sava_files, $_;
		}
	}
}

# Get valid path and maybe change working directory
sub get_full_path {
	if(exists($opt{path})) {
		chdir($opt{path});
		$opt{fullpath} = $opt{path}."\\".$opt{net};
	}
	else {
		$opt{fullpath} = $opt{net};
	}
}

# Gets simulation period
sub get_simulation_period {
	$opt{period} = $VI->Simulation->{Period};
}

# Sets simulation period
sub set_simulation_period {
	verbose("Setting simulation period to ".$opt{period}."\n");
	$VI->Simulation->{Period} = $opt{period};
}

# Set the random seed
sub set_random_seed {
	my $seed = $VI->Simulation->{RandomSeed} + 1;
	verbose("Setting random seed: $seed\n");
	$VI->Simulation->{RandomSeed} = $seed;
}

# Set volume increase percentage if defined
sub set_volume_percentage {
	my $newvol;
	my $VehIs = $VI->Net->VehicleInputs;
	my $Vol = 1 + ($opt{increase_all_volume} / 100);

	foreach my $VehI (in $VehIs) {
		verbose("Adding traffic vol $Vol current vol: ".
			$VehI->AttValue("Volume"));
		$newvol = $VehI->AttValue("Volume") * $Vol;
		$VehI->SetProperty('AttValue',"Volume", $newvol);

		verbose(" new vol: ".$VehI->AttValue("Volume")."\n");
	}
}

# Set volume increase for individual veh inp
# format: increase_vehinp_volume=[vehinp1],[vehinp2]=%:[vehinp3]=%
# e.g.: increase_vehinp_volume=1,2=3:3=5
# adds 3 % to veh inp 1 and 2, and adds 5 % to veh inp 3
sub set_vehinp_volume_percentage {
	my @volcollections = split /:/, $opt{increase_vehinp_volume};
	foreach my $col (@volcollections) {
		my ($veh_inputs, $vol) = split /=/, $col;
		my @inputs = split /,/, $veh_inputs;
		my $volume = 1 + ($vol / 100);

		foreach my $VehInp (@inputs) {
			my $VehI = $VI->Net->VehicleInputs->{$VehInp};
			verbose("Adding $vol % to vehinp: $VehInp. current vol: ".
				$VehI->AttValue("Volume"));
			my $vehvolume = $VehI->AttValue("Volume") * $volume;
			$VehI->SetProperty('AttValue', "Volume", $vehvolume);
			verbose(" new vol: ".$VehI->AttValue("Volume")."\n");
		}
	}
}

# Sets traffic volumes
sub set_traffic_volumes {
	my %touched_input;
#	my @inp = split(/,/, $opt{input});
	my $VehIs = $VI->Net->VehicleInputs
		or die("can't get vehicle inputs\n");

	# Numerically sort each traffic input using the
	# first integer before the = sign.
	foreach my $vi (sort { $a <=> $b } keys %{$opt{vehicleinput}}) {
		my $volume = $opt{vehicleinput}{$vi};
		set_exact_traffic_volume($VehIs, $vi, $volume);
		$touched_input{$vi}=1;
	}

	# Find out which vehicle inputs we haven't touched
	my @untouched_input;
	my @inputs;
	foreach my $v (in $VehIs) { push @inputs, $v->{ID}; }
	foreach my $i (@inputs) {
		push @untouched_input, $i unless exists($touched_input{$i});
	}
	if($#untouched_input > 0) {
		if(exists($opt{"nullify-unused"})) {
			verbose("Nullifying unset inputs\n");
			foreach my $i (@untouched_input) {
				set_exact_traffic_volume($VehIs, $i, 0);
			}
		}
		else {
			verbose("Warning! The following Vehicle Inputs has not been set: ".
				join(", ", @untouched_input) ."\n");
		}

	}
}

# Set exact traffic volume of an individual traffic input
# INPUT: VehInputs ref, volume
sub set_exact_traffic_volume {
	my $VehIs = shift;
	my $vi = shift;
	my $volume = shift;

	my $VehI = $VehIs->GetVehicleInputByNumber($vi)
		or die("can't get vehicle input: $vi\n");
	my $name = $VehI->{Name};
	verbose("Set traffic vol: $vi".
		"\t".$VehI->AttValue("Volume"));

	$VehI->SetProperty('AttValue',"Volume", $volume);
	verbose("\t->\t".$VehI->AttValue("Volume"));

	if ($name ne "") {
		$name =~ s/^/\t(/;
		$name =~ s/$/)/;
	}
	verbose("$name\n");
}

# Sets routing flows
sub set_routing_flows {
	my %touched_route;
	#my @rot = split(/,/, $opt{route});
	my $RotDcs = $VI->Net->RoutingDecisions;

	# Numerically sort each routing using the first
	# integer. Otherwise the first integer after the
	# first : sign.
	foreach my $rt (sort {
		($a =~ /(\d+):/)[0] <=> ($b =~ /(\d+):/)[0]
							||
		($a =~ /:(\d+)/)[0] <=> ($b =~ /:(\d+)/)[0]
	} keys %{$opt{vehicleroutes}}) {
		my ($decno, $rtno) = split /:/, $rt;
		my $volume = $opt{vehicleroutes}{$rt};
		set_exact_routing_volume($RotDcs, $decno, $rtno, $volume);
		$touched_route{$rt}=1;
	}

	# Find out which routes we haven't touched
	my @untouched_route;
	foreach my $de (in $RotDcs) {
		my $deID = $de->{ID};
		my $rts = $de->{Routes};
		foreach my $rt (in $rts) {
			my $rtID = $rt->{ID};
			push @untouched_route, "$deID:$rtID"
				unless exists($touched_route{"$deID:$rtID"});
		}
	}
	if($#untouched_route > 0) {
		if(exists($opt{"fill-unused"})) {
			verbose("Completing unset routes using API - SAVA\n");
			foreach my $r (@untouched_route) {
				my ($dec, $route) = split ":", $r;
				#TODO: Convert decision to veh_nr?
				my $veh_nr;
				if (exists($opt{replaced_input}{$veh_nr})) {
					my $remaining = $opt{vehicleinput}{$veh_nr} -
						$opt{replaced_input}{$veh_nr};
					set_exact_routing_volume($RotDcs, $dec, $route,
							$remaining);
					#TODO: Remove from @untouched_route?
					# or... don't combine fill-unused with nullify..
				}
			}
		}
		if(exists($opt{"nullify-unused"})) {
			verbose("Nullifying unset routes\n");
			foreach my $r (@untouched_route) {
				my ($dec, $route) = split ":", $r;
				set_exact_routing_volume($RotDcs, $dec, $route, 0);
			}
		}
		else {
			verbose("Warning! The following Routes has not been set: ".
				join(", ", @untouched_route) ."\n");
		}
	}
}

# Set exact routing traffic flows
sub set_exact_routing_volume {
	my $RotDcs = shift;
	my $decno = shift;
	my $rtno = shift;
	my $volume = shift;

	my $rt_dec = $RotDcs->GetRoutingDecisionByNumber($decno)
		or die("can't get routing decision: $decno\n");
	my $Route = $rt_dec->Routes->GetRouteByNumber($rtno)
		or die("can't get route: $rtno on routing decision: $decno\n");

	my $dec_name = $rt_dec->{Name};
	my $rt_turn = $Route->{ID};
	$rt_turn =~ s/1/left/;
	$rt_turn =~ s/2/straight/;
	$rt_turn =~ s/3/right/;
	verbose("Set rel. flow for route: $decno:$rtno");
	verbose("\t".$Route->AttValue1("Relativeflow", 0));
	$Route->SetProperty('AttValue1', ("Relativeflow", 0), $volume);
	verbose("\t->\t".$Route->AttValue1("Relativeflow", 0));
	my $human_readable_route_name = "$dec_name, $rt_turn";
	$human_readable_route_name =~ s/^, //;
	verbose("\t($human_readable_route_name)\n");
}

# Copy the result files to new filename
sub rename_results {
	$rsz = $opt{fullpath};
	$rsz =~ s/.inp$/.rsz/i;
	copy($rsz, $opt{rsz}) if(exists($opt{rsz}));

	$rsr = $opt{fullpath};
	$rsr =~ s/.inp$/.rsr/i;
	copy($rsr, $opt{rsr}) if(exists($opt{rsr}));
}

# Print compiled travel time information from the rsz-file
sub print_compiled {
	my @travelname;
	my @traveltime;
	open(RSZ, $rsz);
	while(<RSZ>) {
		chomp;
		s/ //g;
		@travelname = split(/;/) if(/^Name;/);
		@traveltime = split(/;/) if(/^$opt{period}/);
	}
	close RSZ;

	my %travel;
	for (my $i=1; $i<$#traveltime; $i++) {
		$travel{$travelname[$i]} = $traveltime[$i] if($i % 2);
	}

	print "Average travel times on all routes:\n";
	foreach	my $t (sort keys %travel) {
		print "\t$t: $travel{$t} s\n";
	}
}

# Print travel time from rsr-file
# iternation no as argument
sub print_travel_time_stats {
	chdir $org_cwd;	#change back so we can find route-type-file
	my $iteration_no = shift;
	my $tt = TravelTimeStats->new();
	$tt->set_rsz($rsz); # Set RSZ file, so that we get proper route-names
	$tt->route_type_file($opt{"route-type-file"}) if(exists($opt{"route-type-file"}));

	open(RSR, $rsr);
	while(<RSR>) {
		$tt->setdata($_);
	}
	close RSR;
	my $title = "n = $iteration_no: Travel times on all routes";
	$tt->average_travel_times_on_all_routes_table($title);
	get_full_path(); #change back path
}

# Print total travel time stats
sub print_total_time_stats {
	my $tt = shift;
	my $title = "Total travel times on all routes";
	$tt->average_travel_times_on_all_routes_table($title);
}

# Add rsr-data to total stats
sub add_travel_time {
	my $tt = shift;
	$tt->set_rsz($rsz); # Set RSZ file, so that we get proper route-names
	open(RSR, $rsr);
	while(<RSR>) {
		$tt->setdata($_);
	}
	close RSR;
}

# Only print if verbose is specified
sub verbose {
	print shift if (exists($opt{verbose}))
}

# Send email
sub send_email {
	my $log = shift;
	# Get current time
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
	$year += 1900;
	$mon += 1;
	my $time = sprintf("%02d-%02d-%02d", $year,$mon,$mday);

	my $smtp = Net::SMTP->new($opt{"mail-smtp"},
		Hello => $opt{"mail-smtp"},
		Timeout => 60);
	$smtp->mail($opt{"mail-from-name"} . " <". $opt{"mail-from-addr"} .">");
	my @to = split /,/, $opt{"mail-to"};
	$smtp->recipient(@to);
	$smtp->data;
	$smtp->datasend("From: ". $opt{"mail-from-name"} . " <". $opt{"mail-from-addr"} .">\n");
	$smtp->datasend("To: ". $opt{"mail-to"} ."\n");
	$smtp->datasend("Subject: $time ". $opt{"mail-subject"} ."\n");
	$smtp->datasend("\n");

	open(LOG, '<', \$log) or die "Could not open logfile in send_email()";
	while (<LOG>) {
		$smtp->datasend($_);
	}
	close LOG;
	$smtp->dataend;
	$smtp->quit;
}

__END__

=head1 NAME

visperl - run Vissim simulation and save the results

=head1 SYNOPSIS

B<visperl.pl> [B<--path>=I<path>] [B<--net>=I<filename>]
[B<--rsz>=I<filename>] [B<--rsr>=I<filename>] [B<--period>=I<seconds>]
[B<--iterations>=I<no of iterations>] [B<--increase_all_volume>=I<percent>]
[B<--increase_vehinp_volume>=[I<vehinp1,vehinp2=%]:[vehinp3=%]>]
[B<--input>=[I<veh inp>=I<volume>],..]
[B<--route>=[I<routing decision>:I<route>=I<relative traffic flow>],..]
[B<--nullify-unused>] [B<--stdopt>] [B<--compile>] [B<--stat>] [B<--verbose>]
[B<--sava-startline>=I<[line1],[line2],..>]
[B<--sava-endline>=I<[line1],[line2],..>]
[B<--sava-convert-file>=I<filename>]  [B<--route-type-file>=I<filename>]
[B<--reality>] [B<--api-start>=I<HH:MM>]
[B<--api-end>=I<HH:MM>] [B<--api-control-file>=I<filename>]
[B<--ec1-controller>=I<path to ec1-project>] [B<--fill-unused>]
[B<--mail-smtp>=I<hostname>] [B<--mail-from-addr>=I<e-mail>]
[B<--mail-from-name>=I<name>] [B<--mail-subject>=I<subject line>]
[B<--mail-to>=I<[e-mail],..>] [B<--config>=I<filename>]

=head1 DESCRIPTION

visperl.pl runs a Vissim simulation using the given project file. It can
modify certain properties in Vissim (e.g. traffic volume, simulation period)
and rename log file of travel times to a custom name when done.

=head1 OPTIONS

=over 8

=item B<--path>=I<path>

Optional. This is the path to the Vissim project directory. Can be used to
find the Vissim project file (not required) and to rename the rsz- or rsr file if the B<--rsz> or B<--rsr> option has been given.

=item B<--net>=I<filename>

Required. The Vissim project file (without the path if B<--path> has been
given).

=item B<--rsz>=I<filename>

Optional. Enables logging of compiled travel time.
Requires the use of the B<--path> option.
Renames the resulting rsz-file to given filename.

=item B<--rsr>=I<filename>

Optional. Enables logging of raw travel time.
Requires the use of the B<--path> option.
Renames the resulting rsr-file to given filename.

=item B<--period>=I<seconds>

Optional. Run the simulation at given number of seconds. Otherwise it just
uses whatever's default in the project file.

=item B<--iterations>=I<no of iterations>

Optional. Run the simulation given amount of times to ensure the reliability
of the simulation results. Default is 1 iteration.

=item B<--increase_all_volume>=I<percent>

Optional. Increase all individual traffic volumes by given number of percent.
Enter integers; e.g. B<--set_all_volume>=10 means 10% increase of traffic volume.

=item B<--increase_vehinp_volume>=[I<vehinp1,vehinp2=%:vehinp3=%>]

Optional. Increase individual traffic volumes for each vehicle input number
e.g. --increase_vehinp_volume=4,5=10:6=15. This adds 10 % to vehicle input 4 and 5, and 15 % to vehicle input 6..

=item B<--input>=[[I<veh inp>=I<volume>],..]

Optional. Set an exact value of traffic flow in veh/h. e.g. --input=4:100 where 4 is the Vehicle input number and 100 is the traffic flow in vehicles per hour.

=item B<--route>=[[I<routing decision>:I<route>=I<relative traffic flow>],..]

Optional. Set the relative traffic flow for a route. e.g. --route=1:3=100 where 1 is the routing decision, 3 is the route number and 100 is the relative traffic flow.

=item B<--nullify-unused>

Optional. Sets unset vehicle inputs or routing rel. flow (using B<--input>
or B<--route>) to 0. Ignore if B<--input> or B<--route> is not used.
Useful if your traffic statistics doesn't include all inputs/routes.

=item B<--stdopt>

Optional. Sets options using standard input instead. Remove the double dash
('--') before each option. Use a newline to separate each option.
e.g. input=1=51,2=9 on STDIN.

=item B<--compile>

Optional. Outputs compiled travel time statistics similar to the one
B<restid.pl> produces. Bases it's output on the statistics that the
Vissim rsz-file produces.

=item B<--stat>

Optional. Outputs self produced statistics based on raw travel times from
the rsr-file Vissim produces. Includes max, min, variance, and standard
deviation.

=item B<--verbose>

Optional. Increase verbosity level. Outputs status whenever changing
vissim parameters.

=item B<--sava-startline>=I<[line1],[line2],..>

Activates processing of SAVA-data. The numbers(s) or the starting line(s)
which the vehicle passes or might pass. If you enter several numbers,
separate them with a comma (',').

=item B<--sava-endline>=I<[line1],[line2],..>

The number(s) of the ending line(s) which the vehicles passes or might pass.
If you enter several numbers, separate them with a comma (',').

=item B<--sava-convert-file>=I<filename>

Use a file with each sava-data-files printed on each line, instead of
specifying each sava-file as argument.

=item B<--route-type-file>=I<filename>

Use a file to describe of what type a traffic route is of. This produces
statistics that also separates types of traffic.

=item B<--reality>

Compare with reality. Prints SAVA-statistics at the end.

=item B<--api-start>=I<HH:MM>

Specifies the start time for result interpretation.

=item B<--api-end>=I<HH:MM>

Specifies the end time for result interpretation.

=item B<--api-control-file>=I<filename>]

Enables the Axle Passage Interpreter to determine a accurate vehicle flow.
API control file which must contain each API-data file with it's vehicle
input number and file name seprated with a semi-colon, on each line.

=item B<--ec1-controller>=I<path to ec1-project>

Use specified EC-1 controller

=item B<--fill-unused>

=item B<--mail-smtp>=I<hostname>

E-mail the results. Specifies the hostname of the SMTP-server required to
send the email.

=item B<--mail-from-addr>=I<e-mail>

The resulting e-mail will look like it came from this e-mail-address.

=item B<--mail-from-name>=I<name>

The resulting e-mail will look like it came from this name. Use (")-chars
when appropriate.

=item B<--mail-subject>=I<subject line>

Subject line. Use (")-chars when approriate.

=item B<--mail-to>=I<[e-mail],..>

Send the e-mail to these addresss. Separate each address with a (,)-char.

=item B<--config, -f>=I<filename>

Instead of specifying each option on the command line, use a config-file.
All options avalible on the command line is also avalible in the config-file.
Just omit the double dash (--) in front of each option. One option per line.
Don't use the '=' char to separate option from parameter, use blankspace.
Empty lines and lines beginning with a '#'-char are ignored.

=back

=head1 CAVEATS

Remaining issues

=over 8

=item Start of the EC1-simulator might fail

Sometimes visperl is unable to find the EC1-simulator "License" message-box
window and is therefore unable to start the simulator properly.

=item Errors are not logged properly

Any errors or warnings that occur is printed on STDERR and is not included
with the e-mail. It is therefore easy to miss any errors that might have
affected the outcome.

=item Number of necessary simulations

It is possible to calculate the number of needed simulations. Or when
another simulation wouldn't change the total outcome in a simulation
significantly.

=back

=head1 HISTORY

The first version appeared in September 2007.

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.com>

=cut

