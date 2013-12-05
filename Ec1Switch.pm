# Rename 'ini'-style VAP-file's section number in order to fool VAP.dll
# CAVEATS
# * Exiting vissim incorrectly crashes visperl and doesn't restore vap file
#   it leads to incorrect controller used next time since two sections have
#   same name. We should add a check for this.
package Ec1Switch;
use strict;
use File::Copy;
use Tie::File;

sub new {
	my $class = shift;
	my $self = {
		vap_file			=> undef,
		vap_file_backup		=> undef,
	};
	bless $self, $class;
	return $self;
}

sub set_vap_file {
	my $self = shift;
	my $vap_file = shift;
	$self->{vap_file} = $vap_file;
}

sub set_vap_file_backup {
	my $self = shift;
	my $vap_file_backup = shift;
	$self->{vap_file_backup} = $vap_file_backup;
}

sub backup_vap_file {
	my $self = shift;
	copy($self->{vap_file}, $self->{vap_file_backup}) || warn("copy failed $!");
}

sub restore_vap_file {
	my $self = shift;
	return undef unless defined($self->{vap_file_backup});
	copy($self->{vap_file_backup}, $self->{vap_file}) || warn("copy failed $!");
}

sub rename_section {
	my $self = shift;
	my $old_section = shift;
	my $new_section = shift;
	print "Rename section $old_section to $new_section\n";
	print "Using vap file: ". $self->{vap_file} ."\n";
	my @lines;
	tie @lines, 'Tie::File', $self->{vap_file} || die("can't open file: $!\n");
	for (@lines) {
		if (s/^\[$old_section\]/\[$new_section\]/) {
			print "changed: $_\n";
		}
	}
	untie @lines;
}

# Verify that the section name doesn't already exists
sub check_for_section {
	my $self = shift;
	my $section = shift;
	my @lines;
	tie @lines, 'Tie::File', $self->{vap_file} || die("can't open file: $!\n");
	for (@lines) {
		if (/^\[$section\]/) {
			untie @lines;
			return 1;
		}
	}
	untie @lines;
	return undef;
}
1;
