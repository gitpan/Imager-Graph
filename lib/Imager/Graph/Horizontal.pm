package Imager::Graph::Horizontal;

=head1 NAME

  Imager::Graph::Horizontal - A super class for line/bar charts

=cut

use strict;
use vars qw(@ISA);
use Imager::Graph;
@ISA = qw(Imager::Graph);

use constant STARTING_MIN_VALUE => 99999;

=over 4

=item add_data_series(\@data, $series_name)

Add a data series to the graph, of the default type.

=cut

sub add_data_series {
  my $self = shift;
  my $data_ref = shift;
  my $series_name = shift;

  my $series_type = $self->_get_default_series_type();
  $self->_add_data_series($series_type, $data_ref, $series_name);

  return;
}

=item add_column_data_series(\@data, $series_name)

Add a column data series to the graph.

=cut

sub add_column_data_series {
  my $self = shift;
  my $data_ref = shift;
  my $series_name = shift;

  $self->_add_data_series('column', $data_ref, $series_name);

  return;
}

=item add_line_data_series(\@data, $series_name)

Add a line data series to the graph.

=cut

sub add_line_data_series {
  my $self = shift;
  my $data_ref = shift;
  my $series_name = shift;

  $self->_add_data_series('line', $data_ref, $series_name);

  return;
}

=item set_column_padding($int)

Sets the number of pixels that should go between columns of data.

=cut

sub set_column_padding {
  $_[0]->{'custom_style'}->{'column_padding'} = $_[1];
}

=item set_negative_background($color)

Sets the background color used below the x axis.

=cut

sub set_negative_background {
  $_[0]->{'custom_style'}->{'negative_bg'} = $_[1];
}

=item draw()

Draw the graph

=cut

sub draw {
  my ($self, %opts) = @_;

  if (!$self->_valid_input()) {
    return;
  }

  $self->_style_setup(\%opts);

  my $style = $self->{_style};

  my $img = $self->_get_image()
    or return;

  my @image_box = ( 0, 0, $img->getwidth-1, $img->getheight-1 );
  $self->_set_image_box(\@image_box);

  my @chart_box = ( 0, 0, $img->getwidth-1, $img->getheight-1 );
  $self->_draw_legend(\@chart_box);
  if ($style->{title}{text}) {
    $self->_draw_title($img, \@chart_box)
      or return;
  }

  # Scale the graph box down to the widest graph that can cleanly hold the # of columns.
  return unless $self->_get_data_range();
  $self->_remove_tics_from_chart_box(\@chart_box);
  my $column_count = $self->_get_column_count();

  my $width = $self->_get_number('width');
  my $height = $self->_get_number('height');

  my $graph_width = $chart_box[2] - $chart_box[0];
  my $graph_height = $chart_box[3] - $chart_box[1];

  my $col_height = int(($graph_height - 1) / $column_count) -1;
  $graph_height = $col_height * $column_count + 1;

  my $tic_count = $self->_get_x_tics();
  my $tic_distance = int(($graph_width -1) / ($tic_count - 1));
  $graph_width = $tic_distance * ($tic_count - 1);

  my $bottom = $chart_box[1];
  my $left   = $chart_box[0];

  $self->{'_style'}{'graph_width'} = $graph_width;
  $self->{'_style'}{'graph_height'} = $graph_height;

  my @graph_box = ($left, $bottom, $left + $graph_width, $bottom + $graph_height);
  $self->_set_graph_box(\@graph_box);

  $img->box(
            color   => $self->_get_color('outline.line'),
            xmin    => $left,
            xmax    => $left+$graph_width,
            ymin    => $bottom,
            ymax    => $bottom+$graph_height,
            );

  $img->box(
            color   => $self->_get_color('bg'),
            xmin    => $left + 1,
            xmax    => $left+$graph_width - 1,
            ymin    => $bottom + 1,
            ymax    => $bottom+$graph_height-1 ,
            filled  => 1,
            );

  my $min_value = $self->_get_min_value();
  my $max_value = $self->_get_max_value();
  my $value_range = $max_value - $min_value;

  my $zero_position;
  if ($value_range) {
    $zero_position =  $left + (-1*$min_value / $value_range) * ($graph_width-1);
  }

  if ($min_value < 0) {
    $img->box(
            color   => $self->_get_color('negative_bg'),
            xmin    => $left+1,
            xmax    => $zero_position,
            ymin    => $bottom+1,
            ymax    => $bottom+$graph_height - 1,
            filled  => 1,
    );
    $img->line(
            x1 => $zero_position,
            y1 => $bottom,
            x2 => $zero_position,
            y2 => $bottom + $graph_height,
            color => $self->_get_color('outline.line'),
    );
  }

  if ($self->_get_data_series()->{'bar'}) {
    $self->_draw_bars();
  }

  if ($self->_get_x_tics()) {
    $self->_draw_x_tics();
  }
  if ($self->_get_labels()) {
    $self->_draw_y_tics();
  }

  return $self->_get_image();
}

sub _get_data_range {
  my $self = shift;

  my $max_value = 0;
  my $min_value = 0;
  my $column_count = 0;

  my ($b_min, $b_max, $b_cols) = $self->_get_bar_range();

  $min_value = $b_min;
  $max_value = $b_max;
  $column_count = $b_cols;
#  $min_value = $self->_min(STARTING_MIN_VALUE, $c_min, $l_min);
#  $max_value = $self->_max(0, $sc_max, $c_max, $l_max);

  if ($self->_get_number('automatic_axis')) {
    # In case this was set via a style, and not by the api method
    eval { require Chart::Math::Axis; };
    if ($@) {
      return $self->_error("Can't use automatic_axis - $@");
    }

    my $axis = Chart::Math::Axis->new();
    $axis->include_zero();
    $axis->add_data($min_value, $max_value);
    $max_value = $axis->top;
    $min_value = $axis->bottom;
    my $ticks     = $axis->ticks;
    # The +1 is there because we have the bottom tick as well
    $self->set_x_tics($ticks+1);
  }

  $self->_set_max_value($max_value);
  $self->_set_min_value($min_value);
  $self->_set_column_count($column_count);

  return 1;
}

sub _min {
  my $self = shift;
  my $min = shift;

  foreach my $value (@_) {
    next unless defined $value;
    if ($value < $min) { $min = $value; }
  }
  return $min;
}

sub _max {
  my $self = shift;
  my $min = shift;

  foreach my $value (@_) {
    next unless defined $value;
    if ($value > $min) { $min = $value; }
  }
  return $min;
}

sub _get_bar_range {
  my $self = shift;

  my $series = $self->_get_data_series()->{'bar'};
  return (undef, undef, 0) unless $series;

  my $max_value = 0;
  my $min_value = STARTING_MIN_VALUE;
  my $column_count = 0;

  my @series = @{$series};
  foreach my $series (@series) {
    my @data = @{$series->{'data'}};

    foreach my $value (@data) {
      $column_count++;
      if ($value > $max_value) { $max_value = $value; }
      if ($value < $min_value) { $min_value = $value; }
    }
  }

  return ($min_value, $max_value, $column_count);
}


sub _draw_legend {
  my $self = shift;
  my $chart_box = shift;
  my $style = $self->{'_style'};

  my @labels;
  my $img = $self->_get_image();
  if (my $series = $self->_get_data_series()->{'bar'}) {
    push @labels, map { $_->{'series_name'} } @$series;
  }

  if ($style->{features}{legend} && (scalar @labels)) {
    $self->SUPER::_draw_legend($self->_get_image(), \@labels, $chart_box)
      or return;
  }
  return;
}

sub _draw_flat_legend {
  return 1;
}

sub _draw_lines {
  my $self = shift;
  my $style = $self->{'_style'};

  my $img = $self->_get_image();

  my $max_value = $self->_get_max_value();
  my $min_value = $self->_get_min_value();
  my $column_count = $self->_get_column_count();

  my $value_range = $max_value - $min_value;

  my $width = $self->_get_number('width');
  my $height = $self->_get_number('height');

  my $graph_width = $self->_get_number('graph_width');
  my $graph_height = $self->_get_number('graph_height');

  my $line_series = $self->_get_data_series()->{'line'};
  my $series_counter = $self->_get_series_counter() || 0;

  my $has_columns = (defined $self->_get_data_series()->{'column'} || $self->_get_data_series->{'stacked_column'}) ? 1 : 0;

  my $col_width = int($graph_width / $column_count) -1;

  my $graph_box = $self->_get_graph_box();
  my $left = $graph_box->[0] + 1;
  my $bottom = $graph_box->[1];

  my $zero_position =  $bottom + $graph_height - (-1*$min_value / $value_range) * ($graph_height - 1);


  my $line_aa = $self->_get_number("lineaa");
  foreach my $series (@$line_series) {
    my @data = @{$series->{'data'}};
    my $data_size = scalar @data;

    my $interval;
    if ($has_columns) {
      $interval = $graph_width / ($data_size);
    }
    else {
      $interval = $graph_width / ($data_size - 1);
    }
    my $color = $self->_data_color($series_counter);

    # We need to add these last, otherwise the next line segment will overwrite half of the marker
    my @marker_positions;
    for (my $i = 0; $i < $data_size - 1; $i++) {
      my $x1 = $left + $i * $interval;
      my $x2 = $left + ($i + 1) * $interval;

      $x1 += $has_columns * $interval / 2;
      $x2 += $has_columns * $interval / 2;

      my $y1 = $bottom + ($value_range - $data[$i] + $min_value)/$value_range * $graph_height;
      my $y2 = $bottom + ($value_range - $data[$i + 1] + $min_value)/$value_range * $graph_height;

      push @marker_positions, [$x1, $y1];
      $img->line(x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2, aa => $line_aa, color => $color) || die $img->errstr;
    }

    my $x2 = $left + ($data_size - 1) * $interval;
    $x2 += $has_columns * $interval / 2;

    my $y2 = $bottom + ($value_range - $data[$data_size - 1] + $min_value)/$value_range * $graph_height;

    push @marker_positions, [$x2, $y2];
    foreach my $position (@marker_positions) {
      $self->_draw_line_marker($position->[0], $position->[1], $series_counter);
    }
    $series_counter++;
  }

  $self->_set_series_counter($series_counter);
  return;
}

sub _line_marker {
  my ($self, $index) = @_;

  my $markers = $self->{'_style'}{'line_markers'};
  if (!$markers) {
    return;
  }
  my $marker = $markers->[$index % @$markers];

  return $marker;
}

sub _draw_line_marker {
  my $self = shift;
  my ($x1, $y1, $series_counter) = @_;

  my $img = $self->_get_image();

  my $style = $self->_line_marker($series_counter);
  return unless $style;

  my $type = $style->{'shape'};
  my $radius = $style->{'radius'};

  my $line_aa = $self->_get_number("lineaa");
  my $fill_aa = $self->_get_number("fill.aa");
  if ($type eq 'circle') {
    my @fill = $self->_data_fill($series_counter, [$x1 - $radius, $y1 - $radius, $x1 + $radius, $y1 + $radius]);
    $img->circle(x => $x1, y => $y1, r => $radius, aa => $fill_aa, filled => 1, @fill);
  }
  elsif ($type eq 'square') {
    my @fill = $self->_data_fill($series_counter, [$x1 - $radius, $y1 - $radius, $x1 + $radius, $y1 + $radius]);
    $img->box(xmin => $x1 - $radius, ymin => $y1 - $radius, xmax => $x1 + $radius, ymax => $y1 + $radius, @fill);
  }
  elsif ($type eq 'diamond') {
    # The gradient really doesn't work for diamond
    my $color = $self->_data_color($series_counter);
    $img->polygon(
        points => [
                    [$x1 - $radius, $y1],
                    [$x1, $y1 + $radius],
                    [$x1 + $radius, $y1],
                    [$x1, $y1 - $radius],
                  ],
        filled => 1, color => $color, aa => $fill_aa);
  }
  elsif ($type eq 'triangle') {
    # The gradient really doesn't work for triangle
    my $color = $self->_data_color($series_counter);
    $img->polygon(
        points => [
                    [$x1 - $radius, $y1 + $radius],
                    [$x1 + $radius, $y1 + $radius],
                    [$x1, $y1 - $radius],
                  ],
        filled => 1, color => $color, aa => $fill_aa);

  }
  elsif ($type eq 'x') {
    my $color = $self->_data_color($series_counter);
    $img->line(x1 => $x1 - $radius, y1 => $y1 -$radius, x2 => $x1 + $radius, y2 => $y1+$radius, aa => $line_aa, color => $color) || die $img->errstr;
    $img->line(x1 => $x1 + $radius, y1 => $y1 -$radius, x2 => $x1 - $radius, y2 => $y1+$radius, aa => $line_aa, color => $color) || die $img->errstr;
  }
  elsif ($type eq 'plus') {
    my $color = $self->_data_color($series_counter);
    $img->line(x1 => $x1, y1 => $y1 -$radius, x2 => $x1, y2 => $y1+$radius, aa => $line_aa, color => $color) || die $img->errstr;
    $img->line(x1 => $x1 + $radius, y1 => $y1, x2 => $x1 - $radius, y2 => $y1, aa => $line_aa, color => $color) || die $img->errstr;
  }
}

sub _draw_bars {
  my $self = shift;
  my $style = $self->{'_style'};

  my $img = $self->_get_image();

  my $max_value = $self->_get_max_value();
  my $min_value = $self->_get_min_value();
  my $column_count = $self->_get_column_count();

  my $value_range = $max_value - $min_value;

  my $width = $self->_get_number('width');
  my $height = $self->_get_number('height');

  my $graph_width = $self->_get_number('graph_width');
  my $graph_height = $self->_get_number('graph_height');


  my $graph_box = $self->_get_graph_box();
  my $bottom = $graph_box->[1] + 1;
  my $left  = $graph_box->[0];

  my $zero_position =  int($left + (-1*$min_value / $value_range) * ($graph_width-1));

  my $bar_height = int($graph_height / $column_count - 1);

  my $outline_color;
  if ($style->{'features'}{'outline'}) {
    $outline_color = $self->_get_color('outline.line');
  }

  my $series_counter = $self->_get_series_counter() || 0;
  my $col_series = $self->_get_data_series()->{'bar'};
  my $column_padding = $self->_get_number('column_padding') || 0;

  # This tracks the series we're in relative to the starting series - this way colors stay accurate, but the columns don't start out too far to the right.
  my $column_series = 0;

  for (my $series_pos = 0; $series_pos < scalar @$col_series; $series_pos++) {
    my $series = $col_series->[$series_pos];
    my @data = @{$series->{'data'}};
    my $data_size = scalar @data;
    for (my $i = 0; $i < $data_size; $i++) {

      my $y1 = int($bottom + $bar_height * (scalar @$col_series * $i + $series_pos)) + scalar @$col_series * $i + $series_pos + ($column_padding / 2);

      my $y2 = $y1 + $bar_height - $column_padding;

      my $x1 = int($left - ($min_value - $data[$i]) / $value_range * $graph_width);

      my $color = $self->_data_color($series_counter);

      if ($data[$i] > 0) {
        my @fill = $self->_data_fill($series_counter, [$zero_position+1, $y1, $x1, $y2]);
        $img->box(xmax => $x1, xmin => $zero_position+1, ymin => $y1, ymax => $y2, @fill);
        if ($style->{'features'}{'outline'}) {
          $img->box(xmax => $x1, xmin => $zero_position, ymin => $y1, ymax => $y2, color => $outline_color);
        }
      }
      elsif ($data[$i] == 0) {
      }
      else {
        my @fill = $self->_data_fill($series_counter, [$x1, $y1, $zero_position, $y2]);
        $img->box(xmax  => $zero_position , xmin => $x1, ymin => $y1, ymax => $y2, @fill);
        if ($style->{'features'}{'outline'}) {
          $img->box(xmax => $zero_position, xmin => $x1, ymin => $y1, ymax => $y2, color => $outline_color);
        }
      }
    }

    $series_counter++;
    $column_series++;
  }
  $self->_set_series_counter($series_counter);
  return;
}

sub _add_data_series {
  my $self = shift;
  my $series_type = shift;
  my $data_ref = shift;
  my $series_name = shift;

  my $graph_data = $self->{'graph_data'} || {};

  my $series = $graph_data->{$series_type} || [];

  push @$series, { data => $data_ref, series_name => $series_name };

  $graph_data->{$series_type} = $series;

  $self->{'graph_data'} = $graph_data;
  return;
}

=over

=item show_vertical_gridlines()

Shows vertical gridlines at the y-tics.

=cut

sub show_vertical_gridlines {
    $_[0]->{'custom_style'}->{'vertical_gridlines'} = 1;
}

=item use_automatic_axis()

Automatically scale the Y axis, based on L<Chart::Math::Axis>.  If Chart::Math::Axis isn't installed, this sets an error and returns undef.  Returns 1 if it is installed.

=cut

sub use_automatic_axis {
  eval { require Chart::Math::Axis; };
  if ($@) {
    return $_[0]->_error("use_automatic_axis - $@\nCalled from ".join(' ', caller)."\n");
  }
  $_[0]->{'custom_style'}->{'automatic_axis'} = 1;
  return 1;
}


=item set_x_tics($count)

Set the number of X tics to use.  Their value and position will be determined by the data range.

=cut

sub set_x_tics {
  $_[0]->{'x_tics'} = $_[1];
}

sub _get_x_tics {
  return $_[0]->{'x_tics'} || 0;
}

sub _remove_tics_from_chart_box {
  my $self = shift;
  my $chart_box = shift;

  # XXX - bad default
  my $tic_width = $self->_get_y_tic_width() || 10;
  my @y_tic_box = ($chart_box->[0], $chart_box->[1], $chart_box->[0] + $tic_width, $chart_box->[3]);

  # XXX - bad default
  my $tic_height = $self->_get_x_tic_height() || 10;
  my @x_tic_box = ($chart_box->[0], $chart_box->[3] - $tic_height, $chart_box->[2], $chart_box->[3]);

  $self->_remove_box($chart_box, \@y_tic_box);
  $self->_remove_box($chart_box, \@x_tic_box);

  # If there's no title, the y-tics will be part off-screen.  Half of the x-tic height should be more than sufficient.
  my @y_tic_tops = ($chart_box->[0], $chart_box->[1], $chart_box->[2], $chart_box->[1] + int($tic_height / 2));
  $self->_remove_box($chart_box, \@y_tic_tops);

}

sub _get_y_tic_width {
  my $self = shift;

  my $labels = $self->_get_labels();
  my $max_width = 0;
  foreach my $label (@$labels) {
    my @box = $self->_text_bbox($label, 'legend');
    my $width = $box[2] + 5;
    # For the tic itself...
    $width += 10;
    if ($width > $max_width) {
      $max_width = $width;
    }
  }
  return $max_width;
}

sub _get_x_tic_height {
  my $self = shift;

  my $min = $self->_get_min_value();
  my $max = $self->_get_max_value();
  my $tic_count = $self->_get_x_tics();

  my $interval = ($max - $min) / ($tic_count - 1);

  my %text_info = $self->_text_style('legend')
    or return;

  my $max_height = 0;
  for my $count (0 .. $tic_count - 1) {
    my $value = sprintf("%.2f", ($count*$interval)+$min);

    my @box = $self->_text_bbox($value, 'legend');
    my $height = $box[3] - $box[1];

    # For the tic width
    $height += 10;
    if ($height > $max_height) {
      $max_height = $height;
    }
  }


  return $max_height;
}

sub _draw_y_tics {
  my $self = shift;

  my $img = $self->_get_image();
  my $graph_box = $self->_get_graph_box();
  my $image_box = $self->_get_image_box();

  my $labels = $self->_get_labels();

  my $tic_count = (scalar @$labels) - 1;

  my $has_columns = defined $self->_get_data_series()->{'bar'};

  # If we have columns, we want the x-ticks to show up in the middle of the column, not on the left edge
  my $denominator = $tic_count;
  if ($has_columns) {
    $denominator ++;
  }
  my $tic_distance = ($graph_box->[3] - $graph_box->[1]) / ($denominator);
  my %text_info = $self->_text_style('legend')
    or return;

  for my $count (0 .. $tic_count) {
    my $label = $labels->[$count];

    my $x1 = $graph_box->[0] - 5;
    my $x2 = $graph_box->[0] + 5;

    my $y1 = $graph_box->[1] + ($tic_distance * $count);

    if ($has_columns) {
      $y1 += $tic_distance / 2;
    }

    $img->line(x1 => $x1, x2 => $x2, y1 => $y1, y2 => $y1, aa => 1, color => '000000');

    my @box = $self->_text_bbox($label, 'legend')
      or return;

    my $width = $box[2];
    my $height = $box[3];

    $img->string(%text_info,
                 x    => ($x1 - ($width + 5)),
                 y    => ($y1 + ($height / 2)),
                 text => $label
                );

  }

}

sub _draw_x_tics {
  my $self = shift;

  my $img = $self->_get_image();
  my $graph_box = $self->_get_graph_box();
  my $image_box = $self->_get_image_box();

  my $tic_count = $self->_get_x_tics();
  my $min = $self->_get_min_value();
  my $max = $self->_get_max_value();
  my $interval = ($max - $min) / ($tic_count - 1);

  # If we have columns, we want the x-ticks to show up in the middle of the column, not on the left edge
  my $tic_distance = ($graph_box->[2] - $graph_box->[0]) / ($tic_count -1);

  my %text_info = $self->_text_style('legend')
    or return;

  my $show_gridlines = $self->_get_number('vertical_gridlines');
  for my $count (0 .. $tic_count-1) {
    my $x1 = $graph_box->[0] + ($tic_distance * $count);

    my $y1 = $graph_box->[3] + 5;
    my $y2 = $graph_box->[3] - 5;

    my $value = ($count*$interval)+$min;

    $img->line(x1 => $x1, x2 => $x1, y1 => $y1, y2 => $y2, aa => 1, color => '000000');

    my @box = $self->_text_bbox($value, 'legend')
      or return;

    my $width = $box[2];
    my $height = $box[3];

    $img->string(%text_info,
                 x    => ($x1 - ($width / 2)),
                 y    => ($y1 + $height + 5),
                 text => $value
                );

    if ($show_gridlines) {
      # XXX - line styles!
      for (my $i = $graph_box->[1]; $i < $graph_box->[3]; $i += 6) {
        my $y1 = $i;
        my $y2 = $i + 2;
        if ($y2 > $graph_box->[3]) { $y2 = $graph_box->[3]; }
        $img->line(x1 => $x1, x2 => $x1, y1 => $y1, y2 => $y2, aa => 1, color => '000000');
      }
    }
  }
}

sub _valid_input {
  my $self = shift;

  if (!defined $self->_get_data_series() || !keys %{$self->_get_data_series()}) {
    return $self->_error("No data supplied");
  }

  my $data = $self->_get_data_series();
  if (defined $data->{'line'} && !scalar @{$data->{'line'}->[0]->{'data'}}) {
    return $self->_error("No values in data series");
  }
  if (defined $data->{'column'} && !scalar @{$data->{'column'}->[0]->{'data'}}) {
    return $self->_error("No values in data series");
  }
  if (defined $data->{'stacked_column'} && !scalar @{$data->{'stacked_column'}->[0]->{'data'}}) {
    return $self->_error("No values in data series");
  }

  return 1;
}

sub _set_column_count   { $_[0]->{'column_count'} = $_[1]; }
sub _set_min_value      { $_[0]->{'min_value'} = $_[1]; }
sub _set_max_value      { $_[0]->{'max_value'} = $_[1]; }
sub _set_image_box      { $_[0]->{'image_box'} = $_[1]; }
sub _set_graph_box      { $_[0]->{'graph_box'} = $_[1]; }
sub _set_series_counter { $_[0]->{'series_counter'} = $_[1]; }
sub _get_column_count   { return $_[0]->{'column_count'} }
sub _get_min_value      { return $_[0]->{'min_value'} }
sub _get_max_value      { return $_[0]->{'max_value'} }
sub _get_image_box      { return $_[0]->{'image_box'} }
sub _get_graph_box      { return $_[0]->{'graph_box'} }
sub _get_series_counter { return $_[0]->{'series_counter'} }

1;

