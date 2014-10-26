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

plan tests => 2;


my $font = Imager::Font::Test->new();

my $graph = Imager::Graph::Line->new();
$graph->set_image_width(900);
$graph->set_image_height(600);
$graph->set_font($font);

$graph->add_data_series([1, 2]);
$graph->set_labels(['AWWWWWWWWWWWWWWA', 'AWWWWWWWWWWWWWWWWWWWWWWWWWWWWWA']);

my $img = $graph->draw() || warn $graph->error;

cmpimg($img, 'testimg/t33_long_labels.ppm', 200);
$img->write(file=>'testout/t33_long_labels.ppm') or die "Can't save img1: ".$img->errstr."\n";

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

