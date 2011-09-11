#!/usr/bin/perl

# Crisis Memorial Calender Prorotype for Earthquake
# http://bit.ly/eqcal
# MIT License

use strict;
use warnings;
use utf8;
use lib qw(extlib/lib/perl5);
use lib qw(lib);
use JSON;
use pQuery;
require "util.pl";

my $MONMAP = {qw( January 1 February 2 March 3 April 4 May 5 June 6 July 7 August 8 September 9 October 10 November 11 December 12 )};
$MONMAP = {%$MONMAP, map {($_=~/^(...)/)[0] => $MONMAP->{$_}} keys %$MONMAP};

my $DATA_CACHE = "../data/list.json";
my $WIKIPEDIA_BASE = 'http://en.wikipedia.org';
my $WIKIPEDIA_URL = [qw(
http://en.wikipedia.org/wiki/List_of_21st-century_earthquakes
http://en.wikipedia.org/wiki/Historical_earthquakes
http://en.wikipedia.org/wiki/List_of_20th-century_earthquakes
)];
main();

sub main {
    my $list = parse_wikipedia();
    my $json = JSON->new->encode($list) or die "JSON encode failed\n";
    save($DATA_CACHE, $json);
}


# キャッシュなしで Wikipedia のカレンダーページを取り出す
sub parse_wikipedia {
    my $buf = [];
    foreach my $url (@$WIKIPEDIA_URL) {
        info("<<<<", $url);
        my $tmp = each_page($url);
        push(@$buf, @$tmp);
    }
    $buf = [sort {$a->{date} cmp $b->{date}} @$buf];
    $buf;
}

sub each_page {
    my $url = shift;
    my $buf = [];

    my $pq = pQuery($url);
    info(title => $pq->find('title')->text);
    my $tr = $pq->find('#bodyContent table tr');
    info(tr => $tr->length);

    $tr->each(sub {
        my $idx = shift;
        my $tdd = pQuery($_)->find('td');
        return if ($tdd->length < 8);
        my $tdp = [map {pQuery($_)} @$tdd];
        my $date = $tdp->[0]->find('span')->text;
        $date ||= $tdp->[0]->text;
        my $time = $tdp->[1]->text;
        my $place = $tdp->[2]->text;
        my $year;
        if ($date =~ m/^([A-Z][a-z]*)\s+(\d+)[,\s]\s*(\d+)(\D.*)?$/) {
            my $mon = $MONMAP->{$1};
            info("****", "[$1]", $date) unless $mon;
            my $day = $2;
            $year = $3;
            $date = sprintf("%04d-%02d-%02d", $year, $mon, $day);
        } elsif ($date =~ m/^(\d+)\s+([A-Z][a-z]*)\s+(\d+)$/) {
            my $day = $1;
            my $mon = $MONMAP->{$2};
            info("****", "[$2]", $date) unless $mon;
            $year = $3;
            $date = sprintf("%04d-%02d-%02d", $year, $mon, $day);
        } elsif ($date =~ m/^(\d+)-(\d+)-(\d+)$/) {
            $year = $1 - 0;
            $date = sprintf("%04d-%02d-%02d", $year, $2, $3);
        } else {
            ## info(skip => $date, $place);
            return;
        }
        my $lat = $tdp->[3]->text;
        my $lng = $tdp->[4]->text;
        $lat = ($lat =~ /(-?\d+(\.\d+))/)[0];
        $lng = ($lng =~ /(-?\d+(\.\d+))/)[0];
        my $death = $tdp->[5]->text;
        my $mag = $tdp->[6]->text;
        my $see = $tdp->[2]->find('i');
        my $name;
        my $link;
        if ($see && $see->text eq 'see') {
            my $atag = $tdp->[2]->find('a:last');
            $name = $atag->text;
            $link = $atag->[0]->getAttribute('href');
            if ($link && $link =~ m/^\//) {
                $link = $WIKIPEDIA_BASE.$link;
            }
        }
        $place =~ s/\(.*?\)//gs;
        $place =~ s/(;|\.| see ).*$//;
        $place =~ s/\s\s+/ /gs;
        $place =~ s/\s+$//gs;
        unless($name) {
            if ($year && $place !~ /^\d+/) {
                $name = $year . ' ' . $place;
            } else {
                $name = $place;
            }
        }
        ## info($date => "[$name] $lat,$lng <$place>");

        my $hash = {};
        $hash->{name} = $name;
        $hash->{date} = $date;
        $hash->{time} = $time;
        $hash->{lat}  = $lat;
        $hash->{lng}  = $lng;
        $hash->{death} = $death;
        $hash->{mag}  = $mag;
        $hash->{link} = $link;
        $hash->{location} = $place;
        push(@$buf, $hash);
    });
    info('----', (scalar @$buf), 'earthquakes');
    
    $buf;
}
