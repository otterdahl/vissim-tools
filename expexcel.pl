#!/usr/bin/perl -w

use strict;
use Win32::OLE;
use Win32::OLE::Const 'Microsoft Excel';

my $ex;

# use existing instance if Excel is already running
eval {$ex = Win32::OLE->GetActiveObject('Excel.Application')};
die "Excel not installed\n" if $@;
unless (defined $ex) {
	$ex = Win32::OLE->new('Excel.Application')
}

# read data from STDIN
chomp(my @data = <STDIN>);

# get a new workbook
my $book = $ex->Workbooks->Add;
my $sheet = $book->Worksheets(1);

# figure out how many columns in input
my $col = $data[0];
$col =~ s/\w//g;
$col = length($col);
if($col == 0) {
	$col = 'A';
}
elsif($col == 1) {
	$col = 'B';
}

# write data
my @text;
my $row=1;
foreach (@data) {
	@text  = split(/;/);
	$sheet->Range("A$row:$col$row")->{Value} = [@text];
	$row++;
}

my $range = $sheet->Range("A1:$col$row");

# create chart
my $chart = $book->Charts->Add;
$chart->SetSourceData($range, 2);
$chart->{ChartType} = xlXYScatterLines;
#$chart->Location(2, "Blad1");

# make excel visible
$ex->{'Visible'} = 1;

undef $book;
undef $ex;

__END__

=head1 NAME

expexcel - export data to MS Excel and display a chart

=head1 SYNOPSIS

B<expexcel.pl> [I<filename> ...]

=head1 DESCRIPTION

expexcel.pl tries to start MS Excel using OLE/COM, print data and
display a chart using data from standard input or given input files.
The columns in the input data must be separated using semicolons.
Suitable to use in combination with the resformat.pl program.

=head1 AUTHOR

David Otterdahl <david.otterdahl@gmail.com>

=cut
