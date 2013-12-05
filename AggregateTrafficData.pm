# Aggreate traffic data
# a module to coordinate different traffic data sources and hopefully do
# something smart.
# Still in a experminaltal state and not used in visperl yet
# uses manual_data.conf, file for observed traffic data
# use agg_test.pl for testing the module

package AggreagateTrafficData;
use AxlePassageInterpreter;
use Sava2TravelTime;
use TravelTimeStats;
use strict;

sub new {
	my $class = shift;
	my $self = {
		api_start_time		=> undef,
		api_end_time		=> undef,
		sava_start_lines	=> undef,
		sava_end_lines		=> undef,
		sava_convert_file	=> undef,
		traffic_flow		=> undef,
		route_rel_flow		=> undef,
	};
	bless $self, $class;
	return $self;
}

# Get vehicle flow for given vehicle input number
sub get_veh_flow() {
	my $self = shift;
	my $veh_inp = shift;
	return $self->{traffic_flow}{$veh_inp};
}

# Get route relative flow for given decision and route
sub get_route_rel_flow(decision_no, route_no) {
	my $self = shift;
	my $decision_no = shift;
	my $route_no = shift;
	return $self->{route_rel_flow}{$decision_no}{$route_no};
}

# Output all data in table-form?
sub print_all {
	my $self = shift;
	print "Traffic flow:\n";
	foreach my $tf (sort { $a <=> $b } keys %{$self->{traffic_flow}}) {
		print "$tf: ". $self->{traffic_flow}{$tf} ."\n";
	}
	print "Routing flow:\n";
	foreach my $de (sort keys %{$self->{route_rel_flow}}) {
		foreach my $rt (sort keys %{$self->{route_rel_flow}{$de}}) {
			print "$de:$rt: ". $self->{route_rel_flow}{$de}{$rt} ."\n";
		}
	}
}

# Set manual data. Updates both veh_flow and route_rel_flow
# File format yet to be determined.
sub set_manual_data {
	my $self = shift;
	my $manual_data = shift;
	open(MANUAL, $manual_data) or die("Can't open manual data: $!\n");
	while (<MANUAL>) {
		chomp;
		s/#(.*)//;
		s/ //g;
		unless (/^$/) {
			if (/:/) {
				# route
				my ($dec, $route, $vol) = split /:|=/;
				$self->{route_rel_flow}{$dec}{$route} = $vol;
			}
			else {
				# veh inp
				my ($veh_nr, $volume) = split /=/;
				$self->{traffic_flow}{$veh_nr} = $volume;
			}
		}
	}
	close MANUAL;
}

# Sets API-data. Updates only veh_flow. Overwrites!
sub run_api_control_file {
	my $self = shift;
	my $api_control_file = shift;
	open(APICONTROL, $api_control_file) or die("Can't open API-control: $!\n");
	while (<APICONTROL>) {
		unless (/#/) {
			my ($veh_nr, $api_file) = split ";";
			my $api = AxlePassageInterpreter->new();
			$api->{start} = $self->{api_start_time};
			$api->{end} = $self->{api_end_time};
			open(API, $api_file) or die("Can't open API-file: $!\n");
			$api->setlines(<API>);
			close API;

			# Overwrite
			$self->{traffic_flow}{$veh_nr} = $api->incoming_flow();
		}
	}
	close APICONTROL;
}

sub set_api_time_period() {
	my $self = shift;
	$self->{api_start_time} = shift;
	$self->{api_end_time} = shift;
}

# Sets SAVA-data. Update veh_flow. NO Overwrites!
# Remember to set_sava_settings() first!
sub run_sava_file {
	my $self = shift;
	my $sava_control_file = shift;
	my @sava_files;
	open SAVACONTROL, $sava_control_file;
	while (<SAVACONTROL>) {
		chomp;
		unless (/#/) {
			push @sava_files, $_;
		}
	}

	my $sava = Sava2TravelTime->new();
	my $stat = TravelTimeStats->new();
	$sava->set_startline($self->{sava_start_lines});
	$sava->set_endline($self->{sava_end_lines});
	$sava->load_sava_files(@sava_files);

	$stat->set_all_data($sava->get_travel_time());
	$stat->set_convertfile($self->{sava_convert_file});

	foreach my $vehinp (keys %{$stat->stats_input()}) {
		# No Overwrites
		unless (exists($self->{traffic_flow}{$vehinp})) {
			$self->{traffic_flow}{$vehinp} = %{$stat->stats_input()}->{$vehinp};
		}
	}
}

# Set Sava start-, endlines and (optional) sava_convert_file
sub set_sava_settings() {
	my $self = shift;
	$self->{sava_start_lines} = shift;
	$self->{sava_end_lines} = shift;
	$self->{sava_convert_file} = shift;
}

# Update routing with SAVA (and API to fill the gaps)
# Requires:
# - API data to be set on associated veh_inp
# - Only ONE route to be missing
sub sava_route_update {
	my $self = shift;
	my $sava_control_file = shift;
	my @sava_files;
	open SAVACONTROL, $sava_control_file;
	while (<SAVACONTROL>) {
		chomp;
		unless (/#/) {
			push @sava_files, $_;
		}
	}

	my $sava = Sava2TravelTime->new();
	my $stat = TravelTimeStats->new();
	$sava->set_startline($self->{sava_start_lines});
	$sava->set_endline($self->{sava_end_lines});
	$sava->load_sava_files(@sava_files);

	$stat->set_all_data($sava->get_travel_time());
	$stat->set_convertfile($self->{sava_convert_file});

	# Find out which decisions that only have two routes
	my %num_dec;	# Number of decisions
	my %sum_dec;	# sum of volumes in a decision
	foreach my $decroute (keys %{$stat->stats_route()}) {
		my ($dec, $rt) = split /:/, $decroute;
		$num_dec{$rt}++;
		$sum_dec{$dec.$rt} += %{$stat->stats_route()}->{$dec}{$rt};
	}

	# Calculate the third route using current veh inp and sum of the two
	my %missing_route_sum;
	foreach my $ro (%num_dec) {
		if ($num_dec{$ro} == 2) {
			#TODO: How should we know which route belongs to which veh inp?
			# $self->{route_rel_flow}{missing route} = $api - $sum_dec{$ro};
			$missing_route_sum{$ro} = get_veh_inp_from_dec_no($ro) -
				$sum_dec{$ro};
		}
	}
}

# Maybe?
sub overwrite {

}

sub no_overwrite {

}

# Get the vehicle input no using the decision no
# use file "dec_no_to_veh_inp.conf"
sub get_veh_inp_from_dec_no {
	my $self = shift;
	my $dec_no = shift;
	open CONV, "dec_no_to_veh_inp.conf" || die("Could not open convert file: $!");
}
1;
