#!/usr/bin/perl

# Crisis Memorial Calender Pre 2 for Earthquake
# http://bit.ly/eqcal
# MIT License

use strict;
use warnings;
use utf8;
use lib qw(extlib/lib/perl5);
use lib qw(lib);
use JSON;
use XML::TreePP;
require "util.pl";

my $DATA_CACHE = "../data/list.json";
my $DESC_JSON = "../data/desc.json";
my $KML = "../data/eq-map.kml";
my $COPYRIGHT = '';
my $TREEPPOPT = {utf8_flag => 1, first_out => [qw(name description)]};
my $PAGETITLE = 'Wisdom of Earthquakes (Map)';

main();

sub main {
    my $json = load($DATA_CACHE);
    my $list = JSON->new->decode($json);
    $json = load($DESC_JSON);
    my $desc = JSON->new->decode($json);
    out_ics($list, $desc);
}

sub out_ics {
    my $list = shift;
    my $dlist = shift;
    my $mplace = [];

    my $dmap = {map {$_->{link} => $_} @$dlist};

    my $INDEXPAGE = 'http://code.google.com/p/memorial-calendars/';

    my $MONNAME = [qw( January February March April May June July August September October November December )];

    foreach my $hash (@$list) {
      my $desc = "\n";
      $desc .= '<div style="width: 400px;">';
      $desc .= '<h2>'.$hash->{name}."</h2>\n";
      #$desc .= '<div class="pict" style="margin: 4px; text-align: center;">';
      #$desc .= sprintf('<a target="_blank" href="%s" title="%s"><img src="%s"/></a>', $link, $PictureCaption, $PictureURL);
      #$desc .= "</div>\n";
      my $date = $hash->{date};
      $date .= " " . $hash->{time} if $hash->{time};
      $desc .= '<div class="date">Date: ' . $date . "</div>\n";
      my $address = $hash->{location};
      $desc .= '<div class="location">Location: ' . $address . "</div>\n";
      my $mag = $hash->{mag};
      $mag = undef if ($mag eq '?');
      $desc .= '<div class="mag">Magnitude: ' . $mag . "</div>\n" if $mag;
      $desc .= '<div class="deth">Fatalities: ' . $hash->{death} . "</div>\n" if $hash->{death};
      my $link = $hash->{link};
      # $desc .= '<div class="detail">Detail: <a href="' . $link . '">Wikipedia</a>'."</div>\n" if $link;
      my $detail = $dmap->{$link} if $link;
      $desc .= '<div class="detail" style="font-size: 90%; margin-top: 1em;">'. $detail->{desc} . ' (<a href="' . $link . '">Wikipedia</a>)'."</div>\n" if $detail;
      my $lat = $hash->{lat} or next;
      my $lng = $hash->{lng} or next;
      my $coordinates = "$lng,$lat";
      my($year, $mon, $day) = split(/\D/, $hash->{date});
      $mon--;
      my $mname = $MONNAME->[$mon];
      my $title = "$mname $day, $year";
      my $place = {
        # -id  => $HotelID,
        name => $title,
        description => \$desc,
        Point => {
            coordinates => $coordinates,
        },
        address => $address,
        Snippet => {
            '#text'   => $address,
            -maxLines => 1,
        },
      };
      $place->{'atom:link'} = {-href => $hash->{link}} if $hash->{link};
      $mplace->[$mon] ||= [];
      push(@{$mplace->[$mon]}, $place);
    }
    my $folders = [];
    foreach my $mon (0 .. $#$mplace) {
        my $hash = { name => $MONNAME->[$mon], Placemark => $mplace->[$mon] };
        push(@$folders, $hash);
    }
    my $dest = {
        kml => {
            '-xmlns' => "http://www.opengis.net/kml/2.2",
            '-xmlns:atom' => "http://www.w3.org/2005/Atom",
            Document => {
                # Placemark => $places,
                Folder => $folders,
                name => $PAGETITLE,
                'atom:link' => {
                    -href => $INDEXPAGE,
                },
            },
        },
    };
    info(">>>>" => $KML);
    my $tpp = XML::TreePP->new(%$TREEPPOPT);
    $tpp->writefile($KML, $dest);
}
