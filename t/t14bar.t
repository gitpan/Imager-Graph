#!perl -w
use strict;
use Imager::Graph::Bar;
use lib 't/lib';
use Imager::Font::Test;
use Test::More;

-d 'testout' 
  or mkdir "testout", 0700 
  or die "Could not create output directory: $!";

++$|;

use Imager qw(:handy);

plan tests => 7;

my @warned;
local $SIG{__WARN__} =
  sub {
    print STDERR $_[0];
    push @warned, $_[0]
  };


#my $fontfile = 'ImUgly.ttf';
#my $font = Imager::Font->new(file=>$fontfile, type => 'ft2', aa=>1)
#  or plan skip_all => "Cannot create font object: ",Imager->errstr,"\n";
my $font = Imager::Font::Test->new();

my @data = ( 100, 180, 80, 20, 2, 1, 0.5 );
my @labels = qw(alpha beta gamma delta epsilon phi gi);

{
  my $bar = Imager::Graph::Bar->new();
  $bar->set_font($font);
  ok($bar, "creating bar chart object");

  $bar->add_data_series(\@data);
  $bar->set_labels(\@labels);

  my $img1 = $bar->draw();
  ok($img1, "drawing bar chart");

  $img1->write(file=>'testout/t14_bar.ppm') or die "Can't save img1: ".$img1->errstr."\n";
  cmpimg($img1, 'testimg/t14_bar.ppm', 1);
}

{ # alternative interfaces
  my $bar = Imager::Graph::Horizontal->new();
  $bar->set_font($font);
  ok($bar, "creating bar chart object");

  $bar->add_bar_data_series(\@data);
  $bar->set_labels(\@labels);

  my $img1 = $bar->draw();
  ok($img1, "drawing bar chart");

  $img1->write(file=>'testout/t14_bar2.ppm') or die "Can't save img1: ".$img1->errstr."\n";
  cmpimg($img1, 'testimg/t14_bar.ppm', 1);
}

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

