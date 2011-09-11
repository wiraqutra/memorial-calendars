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
use HTML::TagParser;
require "util.pl";

my $DATA_CACHE = "../data/list.json";
my $DESC_FILE = "../data/desc.json";

main();

sub main {
    my $json = load($DATA_CACHE) if (-f $DATA_CACHE);
    my $list = JSON->new->decode($json) if $json;
    out_desc($list);
}

sub out_desc {
    my $list = shift;
    my $out = [];

    foreach my $hash (@$list) {
        my $link = $hash->{link} or next;
        my $html = fetch($link);
        utf8::decode($html);
        my $dom  = HTML::TagParser->new($html);
        my $body = $dom->getElementsByTagName('p') or next;
        $body = $body->innerText() if ref $body;
        $body =~ s/\[\d+\]//g;
        my $hash = {};
        $hash->{link} = $link;
        info($body);
        $hash->{desc} = $body;
        push(@$out, $hash);
    }
    
    my $json = JSON->new->encode($out) or die "JSON encode failed\n";
    save($DESC_FILE, $json);
}
