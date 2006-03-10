
######################################################################
## $Id: ChartDirector.pm 3516 2005-11-09 03:39:36Z spadkins $
######################################################################

package App::Widget::ChartDirector;
$VERSION = do { my @r=(q$Revision: 3516 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r};

use App;
use App::Widget::Graph;
@ISA = ( "App::Widget::Graph" );

use Date::Format;
use Date::Parse;

use strict;

=head1 NAME

App::Widget::ChartDirector - A graphing widget which displays graphs and charts for web applications using the ChartDirector graphing library within the App-Context/App-Widget widget framework

=head1 SYNOPSIS

   $name = "first_name";

   # official way
   use App;
   $context = App->context();
   $w = $context->widget($name);
   # OR ...
   $w = $context->widget($name,
      class => "App::Widget::ChartDirector",
   );

   # internal way
   use App::Widget::ChartDirector;
   $w = App::Widget::ChartDirector->new($name);

=cut

=head1 DESCRIPTION

A graphing widget which displays graphs and charts for web
applications using the ChartDirector graphing library within the
App-Context/App-Widget widget framework.

=cut

sub html {
    &App::sub_entry if ($App::trace);
    my $self = shift;
    my $name = $self->{name};

    my $spec = $self->create_graph_spec();

    my ($html);
    if ($self->{defer_images}) {   # write out the graph spec. produce graph image later.
        my $spec_path = $spec->{spec_path};
        if (open(App::Widget::ChartDirector::FILE, "> $spec_path")) {
            $self->write_graph_spec(\*App::Widget::ChartDirector::FILE, $spec);
            close(App::Widget::ChartDirector::FILE);
            $html .= "<img src=\"$spec->{cgi_url}\"";
            $html .= " height=\"$spec->{height}\"" if ($spec->{height});
            $html .= " width=\"$spec->{width}\"" if ($spec->{width});
            $html .= ">\n";
        }
        else {
            $html .= "[Error creating graph spec $spec_path: $!]";
        }
    }
    else {    # generate graph image now
        eval {
            $html = $self->write_graph_image($spec);
        };
        if ($@) {
            $html .= "[Error creating graph image $spec->{image_path}: $@]";
        }
    }
    if ($self->{debug}) {
        $html .= "<pre>\n";
        foreach my $key (sort keys %$spec) {
            $html .= "$key = ";
            if (ref($spec->{$key}) eq "ARRAY") {
                $html .= "[ " . join(", ", @{$spec->{$key}}) . " ]\n";
            }
            else {
                $html .= "$spec->{$key}\n";
            }
        }
        $html .= "</pre>\n";
    }

    &App::sub_exit($html) if ($App::trace);
    $html;
}

my $serial = 1;

sub create_graph_spec {
    &App::sub_entry if ($App::trace);
    my ($self) = @_;
    my $context = $self->{context};
    my $options = $context->{options};
    my $spec_tempdir   = $options->{tempdir} || "$options->{prefix}/tmp";
    my $image_tempdir  = "$options->{html_dir}/temp";
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $mon++;
    $year += 1900;
    my $datetime = sprintf("%04d%02d%02d-%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec);
    my $unique_tag = $datetime . "-" . $$ . "-" . $serial;
    my $spec_file  = "$unique_tag.graph";
    my $spec_path  = "$spec_tempdir/$spec_file";
    my $image_file = "$unique_tag.png";
    my $image_path = "$image_tempdir/$image_file";
    while (-f $spec_path || -f $image_path) {
        $serial++;
        $unique_tag = $datetime . "-" . $$ . "-" . $serial;
        $spec_file  = "$unique_tag.graph";
        $spec_path  = "$spec_tempdir/$spec_file";
        $image_file = "$unique_tag.png";
        $image_path = "$image_tempdir/$image_file";
    }
    my %spec = %$self;
    delete $spec{context};
    $spec{graphtype}  ||= "bar";
    if ($spec{graphtype} eq "area") {
        $spec{graphtype} = "line";
        $spec{area} = 1;
    }
    elsif ($spec{graphtype} eq "stacked_bar") {
        $spec{graphtype} = "bar";
        $spec{stacked} = 1;
    }
    $spec{height}     ||= 280;
    $spec{width}      ||= 360;
    $spec{spec_file}  = $spec_file;
    $spec{spec_path}  = $spec_path;
    $spec{image_file} = $image_file;
    $spec{image_path} = $image_path;
    $spec{image_url}  = "$options->{html_url_dir}/temp/$image_file";
    $spec{cgi_url}    = "$options->{script_url_dir}/app-cdgraph/$spec_file";
    &App::sub_exit(\%spec) if ($App::trace);
    return(\%spec);
}

sub write_graph_spec {
    &App::sub_entry if ($App::trace);
    my ($self, $fh, $spec) = @_;
    foreach my $key (%$spec) {
        if (!ref($spec->{$key})) {
            print $fh "\$data{$key} = [ ";
            foreach my $value (@{$spec->{$key}}) {
                print $fh "\"$spec->{$key}\", ";
            }
            print $fh "]\n";
        }
        else {
            print $fh "\$data{$key} = \"$spec->{$key}\";\n";
        }
    }
    &App::sub_exit() if ($App::trace);
}

sub read_graph_spec {
    &App::sub_entry if ($App::trace);
    my ($self, $fh, $spec) = @_;
    foreach my $key (%$spec) {
        if (!ref($spec->{$key})) {
            print $fh "\$data{$key} = [ ";
            foreach my $value (@{$spec->{$key}}) {
                print $fh "\"$spec->{$key}\", ";
            }
            print $fh "]\n";
        }
        else {
            print $fh "\$data{$key} = \"$spec->{$key}\";\n";
        }
    }
    &App::sub_exit() if ($App::trace);
}

sub write_graph_image {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    my $graphtype = $spec->{graphtype} || "bar";
    my %known_graphtype = (
        bar   => 1,
        area  => 1,
        line  => 1,
        pie   => 1,
        meter => 1,
    );
    my $html = "";
    if ($known_graphtype{$graphtype}) {
        my $method = "write_${graphtype}_graph_image";
        $self->$method($spec);
        $html .= "<img src=\"$spec->{image_url}\"";
        $html .= " height=\"$spec->{height}\"" if ($spec->{height});
        $html .= " width=\"$spec->{width}\"" if ($spec->{width});
        $html .= ">\n";
    }
    else {
        $html = "[$self->{name}: Unknown graph type ($graphtype)]\n";
    }
    &App::sub_exit() if ($App::trace);
    return($html);
}

sub get_num_dims {
    &App::sub_entry if ($App::trace);
    my ($self, $graphtype) = @_;
    my %dims = (
        bar         => 2,
        area        => 2,
        line        => 2,
        stacked_bar => 2,
        pie         => 1,
        meter       => 0,
    );
    my $num_dims = $dims{$graphtype};
    $num_dims = 2 if (!defined $num_dims);
    &App::sub_exit($num_dims) if ($App::trace);
    return($num_dims);
}

sub new_xy_chart {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    require "perlchartdir.pm";

    my $x = $self->get_x($spec);
    my $width  = $spec->{width}  || 250;
    my $height = $spec->{height} || 250;
    my $left_margin   = $spec->{left_margin};
    my $bottom_margin = $spec->{bottom_margin};
    my $right_margin  = $spec->{right_margin} || 20;
    my $top_margin    = $spec->{top_margin};
    if (!$top_margin) {
        $top_margin = 5;
        $top_margin += 20 if ($spec->{title});
        #$top_margin += 20 if ($spec->{y_labels});
        $top_margin += 8 if ($spec->{"3D"});
    }
    if (!$bottom_margin) {
        $bottom_margin = 10;
        $bottom_margin += 9 if (!$spec->{registered});
        $bottom_margin += 15 if ($x);
        $bottom_margin += 18 if ($spec->{x_title});
    }
    if (!$left_margin) {
        # TODO: This should be sensitive to the width of the numbers in the scale
        my ($y_min, $y_max) = $self->get_y_limits($spec);
        $y_min = int($y_min);
        $y_max = int($y_max);
        my $y_label_len = length($y_max);
        $y_label_len = length($y_min) if (length($y_min) > $y_label_len);
        $left_margin = 20 + $y_label_len * 6;
        $left_margin += 20 if ($spec->{y_title});
    }

    my $c = new XYChart($width, $height);

    my $plot_area = $c->setPlotArea($left_margin, $top_margin,
        $width-$left_margin-$right_margin,
        $height-$top_margin-$bottom_margin);

    # $plot_area->setBackground(0xffffc0, 0xffffe0);  # yellow
    $plot_area->setBackground(0xd8d8ff, 0xe0e0ff);

    $c->addTitle($spec->{title}) if ($spec->{title});

    #Add a legend box at (55, 22) using horizontal layout, with transparent
    #background
    if ($spec->{y_labels}) {
        my $x_adj = 0;
        my $y_adj = -2;
        if ($spec->{"3D"}) {
            $x_adj += 5;
            $y_adj += -5;
        }
        my $legend = $c->addLegend($left_margin+$x_adj, $top_margin+$y_adj, 0);
        $legend->setBackground($perlchartdir::Transparent);
        $legend->setMargin(5);
    }

    $c->yAxis()->setTitle($spec->{y_title}) if ($spec->{y_title});
    $c->setBackground(0xbbbbff);
    #$c->setBackground(perlchartdir::metalColor(0xaaaaff));

    &App::sub_exit($c) if ($App::trace);
    return($c);
}

sub new_pie_chart {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    require "perlchartdir.pm";

    my $x = $self->get_x($spec);
    my $width  = $spec->{width}  || 250;
    my $height = $spec->{height} || 250;
    my $left_margin   = $spec->{left_margin};
    my $bottom_margin = $spec->{bottom_margin};
    my $right_margin  = $spec->{right_margin} || 20;
    my $top_margin    = $spec->{top_margin};
    if (!$top_margin) {
        $top_margin = 5;
        $top_margin += 20 if ($spec->{title});
        $top_margin += 5 if ($spec->{"3D"});
    }
    if (!$bottom_margin) {
        $bottom_margin = 10;
        $bottom_margin += 9 if (!$spec->{registered});
        $bottom_margin += 15 if ($x);
    }
    if (!$left_margin) {
        $left_margin = 20;
    }
    my $c = new PieChart($width, $height);
    my $center_x = int($width/2);
    my $center_y = int(($height - 20)/2);
    my $radius   = (($center_x > $center_y) ? $center_y : $center_x) - 40;
    $c->setPieSize($center_x, $center_y, $radius);

    $c->addTitle($spec->{title}) if ($spec->{title});

    &App::sub_exit($c) if ($App::trace);
    return($c);
}

sub new_meter_chart {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    require "perlchartdir.pm";

    my $x = $self->get_x($spec);
    my $width  = $spec->{width}  || 250;
    my $height = $spec->{height} || 180;
    my $left_margin   = $spec->{left_margin};
    my $bottom_margin = $spec->{bottom_margin};
    my $right_margin  = $spec->{right_margin} || int($width * 0.08);
    my $top_margin    = $spec->{top_margin};
    if (!$top_margin) {
        $top_margin = 5;
        $top_margin += 20 if ($spec->{title});
        $top_margin += 5 if ($spec->{"3D"});
    }
    if (!$left_margin) {
        $left_margin = $right_margin;
    }
    if (!$bottom_margin) {
        $bottom_margin = 10;
        $bottom_margin += 9 if (!$spec->{registered});
        $bottom_margin += 15 if ($x);
    }
    my $c = new AngularMeter($width, $height, perlchartdir::metalColor(0xaaaaff), 0x0, 2);
    my $max_width_radius = int(($width - $left_margin - $right_margin)/2);
    my $max_height_radius = $height - $top_margin - $bottom_margin;
    my $radius   = ($max_width_radius > $max_height_radius) ? $max_height_radius : $max_width_radius;
    my $center_x = $left_margin + $max_width_radius;
    my $center_y = int(($height - $bottom_margin - $top_margin + $radius)/2) + $top_margin;
    $spec->{radius}   = $radius;
    $spec->{center_x} = $center_x;
    $spec->{center_y} = $center_y;
    $c->setMeter($center_x, $center_y, $radius, -90, 90);

    $c->addTitle($spec->{title}) if ($spec->{title});

    &App::sub_exit($c) if ($App::trace);
    return($c);
}

sub write_bar_graph_image {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    my $c = $self->new_xy_chart($spec);
    my $x  = $self->get_x($spec);
    my $yn = $self->get_y($spec);
    my ($layer);
    if ($#$yn > 0) {
        if ($spec->{stacked}) {
            my $three_d_depth = $spec->{"3D"} ? 8 : 0;
            $layer = $c->addBarLayer2($perlchartdir::Stack, $three_d_depth);
            my $y_labels = $spec->{y_labels} || [];
            for (my $i = 0; $i <= $#$yn; $i++) {
                $layer->addDataSet($yn->[$i], -1, $y_labels->[$i]);
            }
            #Enable bar label for the whole bar
            #$layer->setAggregateLabelStyle();
            #Enable bar label for each segment of the stacked bar
            #$layer->setDataLabelStyle();
        }
        else {
            $layer = $c->addBarLayer2($perlchartdir::Side, $#$yn + 1);
            my $y_labels = $spec->{y_labels} || [];
            for (my $i = 0; $i <= $#$yn; $i++) {
                $layer->addDataSet($yn->[$i], -1, $y_labels->[$i]);
            }
            #Enable bar label for the whole bar
            $layer->setAggregateLabelStyle();
            if ($spec->{"3D"}) {
                $layer->set3D(5,0);
                $layer->setBarGap(0.2, 0.03);
            }
            else {
                $layer->set3D(0,0);
                if ($spec->{overlap}) {
                    $layer->setOverlapRatio(($spec->{overlap} >= 1) ? 0.3 : $spec->{overlap})
                }
                else {
                    $layer->setBarGap(0.2, 0.03);
                }
            }
        }
    }
    elsif ($#$yn > -1) {
        $layer = $c->addBarLayer($yn->[0]);
        $layer->set3D() if ($spec->{"3D"});
    }

    $self->set_x_axis($spec, $c, $layer, $x);

    $c->makeChart($spec->{image_path});
    &App::sub_exit() if ($App::trace);
}

sub set_x_axis {
    my ($self, $spec, $chart, $layer, $x) = @_;
    my $x_title = $spec->{x_title} || "";
    if ($x && $#$x > -1) {
        my ($begin_datetime, $end_datetime, $begin_time, $end_time, $begin_yr, $end_yr);
        if ($x->[0] =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
            #my $bar_offset = ($spec->{graphtype} =~ /bar/) ? 24*3600 : 0;
            my $bar_offset = 0;
            $begin_datetime = $bar_offset ? time2str("%Y-%m-%d", str2time($x->[0]) - $bar_offset) : $x->[0];
            if ($begin_datetime =~ /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/) {
                $begin_yr   = $1;
                $begin_time = &perlchartdir::chartTime($1, $2, $3);
            }
            $end_datetime = $bar_offset ? time2str("%Y-%m-%d", str2time($x->[$#$x]) + $bar_offset) : $x->[$#$x];
            if ($end_datetime =~ /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/) {
                $end_yr   = $1;
                $end_time = &perlchartdir::chartTime($1, $2, $3);
            }
            $chart->xAxis()->setDateScale($begin_time, $end_time);
            my (@x_date);
            for (my $i = 0; $i <= $#$x; $i++) {
                if ($x->[$i] =~ /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/) {
                    $x_date[$i] = &perlchartdir::chartTime($1, $2, $3);
                }
                else {
                    $x_date[$i] = $perlchartdir::NoValue;
                }
            }
            $x_title .= " " if ($x_title);
            $x_title .= "($begin_yr";
            $x_title .= "-$end_yr" if ($end_yr ne $begin_yr);
            $x_title .= ")";
            $chart->xAxis()->setLabelFormat("{value|mm/dd}");
            $layer->setXData(\@x_date);
        }
        elsif ($x->[0] =~ /^[0-9]+$/) {
            $layer->setXData($x);
        }
        else {
            $chart->xAxis()->setLabels($x);
        }
    }
    if ($spec->{graphtype} ne "pie" && $spec->{graphtype} ne "meter") {
        $chart->xAxis()->setTitle($x_title) if ($x_title);
    }
}

sub write_line_graph_image {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    my $c = $self->new_xy_chart($spec);

    #Display 1 out of 3 labels on the x-axis.
    # $c->xAxis()->setLabelStep(3);

    #Set the labels on the x axis by spreading the labels evenly between the first
    #point (index = 0) and the last point (index = noOfPoints - 1)
    # $c->xAxis()->setLinearScale(0, $noOfPoints - 1, $labels);
    # $c->xAxis()->setLinearScale(0, 2, $x);

    my $x = $self->get_x($spec);
    my $yn = $self->get_y($spec);
    my ($layer, $dataset);
    my @symbols = (
        { symbol => $perlchartdir::SquareSymbol,  size => 7, },
        { symbol => $perlchartdir::DiamondSymbol, size => 9, },
        { symbol => $perlchartdir::CircleShape,   size => 7, },
        { symbol => $perlchartdir::TriangleShape, size => 8, },
    );
    if ($spec->{area}) {
        $layer = $c->addAreaLayer2($perlchartdir::Stack);
        $spec->{stacked} = 0;  # stacking is done for us in the area layer
    }
    else {
        $layer = $c->addLineLayer2();
        $layer->setLineWidth(2);
    }
    $layer->set3D(5) if ($spec->{"3D"});
    if ($#$yn > 0) {
        my ($stacked_y, $y, $dataset);
        if ($spec->{stacked}) {
            $stacked_y = [ ];  # make a copy
        }
        my $y_labels = $spec->{y_labels} || [];
        for (my $i = 0; $i <= $#$yn; $i++) {
            $y = $yn->[$i];
            if ($spec->{stacked}) {
                for (my $j = 0; $j <= $#$y; $j++) {
                    $stacked_y->[$j] += $y->[$j];
                }
                $y = $stacked_y;
            }
            $dataset = $layer->addDataSet($y, -1, $y_labels->[$i]);
            $dataset->setDataSymbol($self->sym($i, \@symbols)) if ($spec->{points});
        }
    }
    elsif ($#$yn > -1) {
        $layer = $c->addLineLayer($yn->[0]);
        $layer->setLineWidth(2);
    }
    if ($spec->{point_labels}) {
        my $label_format = $spec->{point_labels};
        $label_format = "{value|0}" if ($label_format eq "1");
        $layer->setDataLabelFormat($label_format);
    }

    $self->set_x_axis($spec, $c, $layer, $x);

    $c->makeChart($spec->{image_path});
    &App::sub_exit() if ($App::trace);
}

sub sym {
    &App::sub_entry if ($App::trace);
    my ($self, $series, $symbols) = @_;
    my $idx = $series % ($#$symbols + 1);
    my $symboldef = $symbols->[$idx];
    &App::sub_exit($symboldef->{symbol}, $symboldef->{size}) if ($App::trace);
    return($symboldef->{symbol}, $symboldef->{size});
}

##Add a legend box at (400, 100)
#$c->addLegend(400, 100);
##Add a stacked bar layer and set the layer 3D depth to 8 pixels
#my $layer = $c->addBarLayer2($perlchartdir::Stack, 8);
##Add the three data sets to the bar layer
#$layer->addDataSet($data0, 0xff8080, "Server # 1");
#$layer->addDataSet($data1, 0x80ff80, "Server # 2");
#$layer->addDataSet($data2, 0x8080ff, "Server # 3");

# TODO: this needs more work before it really works
sub write_meter_graph_image {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    my $c = $self->new_meter_chart($spec);
    my $x = $self->get_x($spec);
    my $yn = $self->get_y($spec) || [[]];
    my $value = $yn->[0][0];
    my $radius   = $spec->{radius};
    my $center_x = $spec->{center_x};
    my $center_y = $spec->{center_y};

    my $y_max = $spec->{y_max} || 100;
    my ($major_tick, $minor_tick, $micro_tick);
    {
        my $y_mantissa = $y_max;
        my $y_scale = 1;
        while ($y_mantissa > 1.0) {
            $y_mantissa /= 10;
            $y_scale    *= 10;
        }
        if ($y_mantissa > 0.5) {
            $y_max = $y_scale;
            $minor_tick = $y_max/10;
            $micro_tick = $y_max/20;
        }
        elsif ($y_mantissa > 0.2) {
            $y_max = 0.5 * $y_scale;
            $minor_tick = $y_max/25;
            $micro_tick = undef;
        }
        else {
            $y_max = 0.2 * $y_scale;
            $minor_tick = $y_max/10;
            $micro_tick = $y_max/20;
        }
        $major_tick = $y_max/5;
    }

    my $y_red = $spec->{y_red} || ($y_max * 0.80);
    my $y_yellow = $spec->{y_yellow} || ($y_max * 0.60);

    #Meter scale is 0 - 100, with major tick every 20 units, minor tick every 10
    #units, and micro tick every 5 units
    $c->setScale(0, $y_max, $major_tick, $minor_tick, $micro_tick);
    #Set 0 - 60 as green (66FF66) zone
    $c->addZone(0, $y_yellow, 0, $radius, 0x66ff66);
    #Set 60 - 80 as yellow (FFFF33) zone
    $c->addZone($y_yellow, $y_red, 0, $radius, 0xffff33);
    #Set 80 - 100 as red (FF6666) zone
    $c->addZone($y_red, $y_max, 0, $radius, 0xff6666);
    #Add a text label centered at (100, 60) with 12 pts Arial Bold font
    if ($spec->{y_title}) {
        $c->addText($center_x, $center_y-int($radius * 0.35), $spec->{y_title},
            "arialbd.ttf", 11, $perlchartdir::TextColor, $perlchartdir::Center);
    }

    my $x_title = "";
    $x_title = $spec->{x_title} if ($spec->{x_title});
    if ($x) {
        $x_title .= ": " if ($x_title);
        $x_title .= $x->[0];
    }
    if ($spec->{y_labels}) {
        if ($x_title) {
            $x_title .= " ($spec->{y_labels}[0])";
        }
        else {
            $x_title = $spec->{y_labels}[0];
        }
    }
    if ($x_title) {
        $c->addText($center_x, $center_y+18, $x_title,
            "arialbd.ttf", 10, $perlchartdir::TextColor, $perlchartdir::Center);
    }

    #Add a text box at the top right corner of the meter showing the value formatted
    #to 2 decimal places, using white text on a black background, and with 1 pixel
    #3D depressed border
    $c->addText($center_x + int($radius * 0.7), $center_y - int($radius * 1.0),
        $c->formatValue($value, "2"),
        "arial.ttf", 8, 0xffffff)->setBackground(0x0, 0, -1);

    #Add a semi-transparent blue (40666699) pointer with black border at the
    #specified value
    $value = $y_max if ($value > $y_max);
    $value = 0 if ($value < 0);
    $c->addPointer($value, 0x40666699, 0x0);
    $c->xAxis()->setLabels($x);
    $c->makeChart($spec->{image_path});
    &App::sub_exit() if ($App::trace);
}

sub write_pie_graph_image {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    my $c = $self->new_pie_chart($spec);
    my $x = $self->get_x($spec);
    my $yn = $self->get_y($spec);
    my $y = $yn->[0];
    if ($#$yn > 0) {
    }
    $c->setData($y, $x);
    $c->set3D() if ($spec->{"3D"});
    $c->xAxis()->setLabels($x);
    $c->makeChart($spec->{image_path});
    &App::sub_exit() if ($App::trace);
}

#my $data = [25, 18, 15, 12, 8, 30, 35];
##The labels for the pie chart
#my $labels = ["Labor", "Licenses", "Taxes", "Legal", "Insurance", "Facilities",
#    "Production"];
##Create a PieChart object of size 360 x 300 pixels
#my $c = new PieChart(360, 300);
##Set the center of the pie at (180, 140) and the radius to 100 pixels
#$c->setPieSize(180, 140, 100);
##Add a title to the pie chart
#$c->addTitle("Project Cost Breakdown");
##Draw the pie in 3D
#$c->set3D();
##Set the pie data and the pie labels
#$c->setData($data, $labels);

# TODO: This one doesn't work yet
sub write_step_graph_image_step {
    &App::sub_entry if ($App::trace);
    my ($self, $spec) = @_;
    require "perlchartdir.pm";

    #Create a XYChart object of size 500 x 270 pixels, with a pale blue (0xe0e0ff)
    #background, a light blue (0xccccff) border, and 1 pixel 3D border effect.
    my $c = new XYChart(800, 350, 0xe0e0ff, 0xccccff, 1);

    #Set the plotarea at (50, 50) and of size 420 x 180 pixels, using white
    #(0xffffff) as the plot area background color. Turn on both horizontal and
    #vertical grid lines with light grey color (0xc0c0c0)
    $c->setPlotArea(50, 50, 720, 260, 0xffffff)->setGridColor(0xc0c0c0, 0xc0c0c0);

    #Add a legend box at (55, 25) (top of the chart) with horizontal layout. Use 10
    #pts Arial Bold Italic font. Set the background and border color to Transparent.
    $c->addLegend(55, 20, 0, "arialbi.ttf", 10)->setBackground($perlchartdir::Transparent);

    #Add a title to the chart using 14 points Times Bold Itatic font, using blue
    #(0x9999ff) as the background color
    $c->addTitle("Rate History", "arialbi.ttf", 12)->setBackground(0x9999ff);

    #Set the y axis label format to display a percentage sign
    #$c->yAxis()->setLabelFormat("{value}%");

    my $labels = $spec->{labels} || [ "Unknown" ];
    my $default_colors =
        [ 0x0000ff, 0x00ff00, 0xff0000, 0x00ffff, 0xff00ff, 0xffff00,
          0x111199, 0x119911, 0x991111, 0x119999, 0x991199, 0x999911,
          0x3333dd, 0x33dd33, 0xdd3333, 0x33dddd, 0xdd33dd, 0xdddd33,
          0x2222bb, 0x22bb22, 0xbb2222, 0x22bbbb, 0xbb22bb, 0xbbbb22 ];
    my $colors = $spec->{colors} || $default_colors;

    my ($label, $color, $step_xaxis, $xaxis, $yaxis, $layer);
    for (my $i = 0; $i <= $#$labels; $i++) {
        $label = $labels->[$i];
        $color = $colors->[$i] || 0;
        if ($color =~ /^0[xX][0-9A-Fa-f]+$/) {
            $color = eval $color;
        }
        $xaxis = $spec->{"x$i"} || [ $i, $i+1, $i+2, $i+3 ];
        $yaxis = $spec->{"y$i"} || [ $i, $i+1, $i+2, $i+3 ];

        # set the xAxis scale
        #$c->xAxis()->setLinearScale($xaxis->[0] - 1, $xaxis->[$#$xaxis], 1, 0);
        $c->xAxis()->setAutoScale(0,0,1);
        $c->yAxis()->setAutoScale(0,0,1);
        $c->xAxis()->setIndent(1);

        # we decrement the $step_xaxis values by a day to account for the fact that
        # the step function runs from left to right but that the spec-> occurred
        # from right to left.
        $step_xaxis = [ @$xaxis ];   # make a copy
        for (my $x = 0; $x <= $#$step_xaxis; $x++) {
            $step_xaxis->[$x]--;
        }

        #Add a step line layer to the chart and set the line width to 2 pixels
        $layer = $c->addStepLineLayer($yaxis, $color, $label);
        #$layer->setXData($step_xaxis);
        $layer->setLineWidth(2);

        # Add a line layer to the chart
        # $layer = $c->addLineLayer();
        # Add the line. Plot the points with a 9 pixel diamond symbol
        # $layer->addDataSet($yaxis, $color)->setDataSymbol( $perlchartdir::DiamondSymbol, 9);
        # Enable data label on the data points. Set the label format to nn%.
        # $layer->setDataLabelFormat("{value}");
    }

    print $c->makeChart($spec->{image_path});
    &App::sub_exit() if ($App::trace);
}

1;

