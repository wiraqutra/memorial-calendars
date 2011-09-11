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
use pQuery;
require "util.pl";

my $DATA_CACHE = "../data/list.json";
my $ICAL_FILE = "../data/eq-ical.ics";

main();

sub main {
    my $json = load($DATA_CACHE) if (-f $DATA_CACHE);
    my $list = JSON->new->decode($json) if $json;
    out_ics($list);
}

sub out_ics {
    my $list = shift;
    my $calyear = (localtime)[5] + 1900;
    my $out = [];
    push(@$out, "BEGIN:VCALENDAR\n");
    push(@$out, "VERSION:2.0\n");
    foreach my $hash (@$list) {
        my $title = $hash->{name};
        my($year, $mon, $day) = split(/-/, $hash->{date});
        next unless($year && $mon && $day);
        my $date = sprintf("%04d%02d%02d", $calyear, $mon, $day);
        info($date, $title);
        my $link = $hash->{link};
        push(@$out, "BEGIN:VEVENT\n");
        my $lname = lc(($title =~ /([A-Za-z]+)/)[0]);
        my $uid = $date.'-'.$lname.'-earthquake@kawa.net';
        push(@$out, "UID:$uid\n");
        push(@$out, "DTSTART;VALUE=DATE:$date\n");
        push(@$out, "DTEND;VALUE=DATE:$date\n");
        my $place = $hash->{location};
        push(@$out, "LOCATION:$place\n") if $place;
        my $lat = $hash->{lat};
        my $lng = $hash->{lng};
        my $geo = sprintf("%+.6f,%+.6f", $lat, $lng) if ($lat && $lng);
        # push(@$out, "GEO:$geo\n") if $geo;
        push(@$out, "SUMMARY:$title\n") if $title;
        push(@$out, "DESCRIPTION:$link\n") if $link;
        push(@$out, "URL:$link\n") if $link;
        push(@$out, "STATUS:CONFIRMED\n");
        push(@$out, "CLASS:PUBLIC\n");
        push(@$out, "END:VEVENT\n");
    }
    push(@$out, "END:VCALENDAR\n");
    
    # iCal ファイルに保存する
    save($ICAL_FILE, $out);
}
