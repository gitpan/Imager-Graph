#!perl -w
use strict;
use Imager::Graph::Line;
use lib 't/lib';
use Imager::Font::Test;
use Test::More;

-d 'testout' 
  or mkdir "testout", 0700 
  or die "Could not create output directory: $!";

++$|;

my @warned;
local $SIG{__WARN__} =
  sub {
    print STDERR $_[0];
    push @warned, $_[0]
  };


use Imager qw(:handy);

plan tests => 4;

#my $fontfile = 'ImUgly.ttf';
#my $font = Imager::Font->new(file=>$fontfile, type => 'ft2', aa=>1)
#  or plan skip_all => "Cannot create font object: ",Imager->errstr,"\n";
my $font = Imager::Font::Test->new();

my @data = (1 .. 1000);
my @labels = qw(alpha beta gamma delta epsilon phi gi);

my $line = Imager::Graph::Line->new();
ok($line, "creating line chart object");
$line->set_font($font);

$line->add_data_series(\@data, "Data series 1");
$line->set_labels(\@labels);
$line->show_legend();

my $img1 = $line->draw();
ok($img1, "drawing line chart");

$img1->write(file=>'testout/t32_series.ppm') or die "Can't save img1: ".$img1->errstr."\n";
cmpimg($img1, 'testimg/t32_series.ppm', 1);

unless (is(@warned, 0, "should be no warnings")) {
  diag($_) for @warned;
}


sub cmpimg {
  my ($img, $file, $limit) = @_;

  $limit ||= 10000;

  my $cmpimg = Imager->new;
  $cmpimg->read(file=>$file)
    or return ok(0, "Cannot read $file: ".$cmpimg->errstr);
  my $diff = Imager::i_img_diff($img->{IMG}, $cmpimg->{IMG});
  cmp_ok($diff, '<', $limit, "Comparison to $file ($diff)");

}
