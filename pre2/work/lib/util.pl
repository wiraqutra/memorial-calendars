use strict;
use warnings;
use utf8;
use Cache::File;
use URI::Fetch;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $name = ($0 =~ m#/?([^/\.]+)[^/]+?$#)[0];
my $CACHE_ROOT    = "/tmp/$name-cache";
my $CACHE_EXPIRES = $ENV{CACHE_EXPIRES} || '1440 min';
my $CACHE_PREFIX  = "$name-util;";
my $cache;

sub save {
    my $file = shift;
    my $buf  = shift;
    info(">>>>", $file);
    open(OUT, ">", $file) or die "$! - $file\n";
    binmode OUT, ":utf8";
    print OUT (ref $buf) ? @$buf : $buf;
    close(OUT);
}

sub load {
    my $file = shift;
    info("<<<<", $file);
    open(IN, $file) or die "$! - $file\n";
    binmode IN, ":utf8";
    local $/ = undef;
    my $text = <IN>;
    close(IN);
    # utf8::decode($text);
    $text;
}

sub info {
    local $, = " ";
    print STDERR @_, "\n";
}

sub show {
    my $name = shift;
    my $data = shift;
    require JSON;
    my $dump = JSON->new->utf8->encode($data);
    info($name, ":", $dump);
}

sub init_cache {
    mkdir($CACHE_ROOT, 0755) unless -d $CACHE_ROOT;
    $cache = Cache::File->new(cache_root => $CACHE_ROOT, cache_depth => 1, default_expires => $CACHE_EXPIRES);
}

sub fetch {
    my $uri = shift;
    my $encoded = $uri;
    $encoded =~ s/([^\x01-\x7E]|\\)/sprintf("\\u%04X", ord($1))/ge;
    # info($uri, $encoded) if ($uri ne $encoded);
    my $key = $CACHE_PREFIX.$encoded;
    init_cache() unless ref $cache;
    my $prev = $cache->get($key);
    print STDERR "==== $uri\n" if $prev;
    return $prev if $prev;
    print STDERR "<<<< $uri\n";
    my $res = URI::Fetch->fetch($uri);
    unless($res) {
        my $mes = URI::Fetch->errstr;
        print STDERR "**** ", $mes, "\n";
        return undef;
    }
    sleep 1;
    my $content = $res->content();
    $cache->set($key, $content);
    $content;
}

sub get_location {
    my $short = shift;
    my $key = $CACHE_PREFIX.$short;
    init_cache() unless ref $cache;
    my $prev = $cache->get($key);
    print STDERR "==== $short\n" if $prev;
    return $prev if $prev;

    print STDERR "<--- $short\n";
    my $ua = LWP::UserAgent->new;
    $ua->max_redirect(0);
    my $res = $ua->head($short);
    my $url = $res->header("Location");
    $cache->set($key, $url);
    print STDERR "---> $url\n";
    $url;
}

;1;
