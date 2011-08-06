#!/usr/bin/perl

# Crisis Memorial Calender Prorotype for Earthquake
# http://bit.ly/eqcal
# MIT License
# 
# 使い方：
# $ parse-wikipedia.pl '地震' out/eq.ics
# 
# やっていること：
# http://ja.wikipedia.org/wiki/1月1日
#「1月1日」から「12月31日」までの Wikipedia ページをパースする。
# 指定した正規表現（地震）にマッチするイベントについて iCal ファイルを生成する。
# 
# TODO:
#・関係のない日付も載ってしまうので、地震に限れば、ソースは「地震の年表」の方が良さそう。
# http://ja.wikipedia.org/wiki/地震の年表
#・キャッシュしてるけど、Wikipedia に1秒おきにアクセスしていいの？API？
#・今年1月〜12月のカレンダーに登録してるけど、来年は空になってる
#・iCal 形式でいいの？XML の方が使いやすそう
#・現状の Google Calendar インポートは手動。自動更新する仕組みの実現方法が不明
#・ちゃんと MIT License を表記しないと
#・要は、最初から作り直す必要がある

use strict;
use warnings;
use utf8;
use lib qw(extlib/lib/perl5);
use lib qw(lib);
use XML::TreePP;
use Time::Local;
use JSON;
require "util.pl";

my $ICAL_FILE = "out/eq.ics";
my $CACHE_FILE = "data/calendar.json";
my $WIKIPEDIA_QUERY = "http://ja.wikipedia.org/wiki/";
my $WIKIPEDIA_TOP = "http://ja.wikipedia.org";
my $TREEPP_OPT = {force_array => [qw(ul li a)]};
my $FORWARD_ERASER = qr{^.*<h2>[^\r\n]*>できごと<[^\r\n]*</h2>}s;
my $BACKWARD_ERASER = qr{<h2>.*$}s;
my $CRISIS_MATCH = qr{(.+地震$|震災)};

main();

sub main {
    # マッチ
    my $regex = $CRISIS_MATCH;
    if ($ARGV[0]) {
        $regex = $ARGV[0];
        utf8::decode($regex);
    } 
    
    # 出力ファイル名
    my $file = $ARGV[1] || $ICAL_FILE;

    # Wikipeida から「できごと」情報を取り出す
    my $list = read_wikipedia() or die "load failed\n";
    info("total events", scalar @$list);
    die "No item found\n" unless scalar @$list;

    # 対象の「できごと」を絞り込む
    $list = event_grep($list, $regex);
    info("match events", scalar @$list);
    die "No item found\n" unless scalar @$list;

    # 重複登場した「できごと」を省く
    $list = event_sort($list);
    $list = event_uniq($list);
    info("uniq events", scalar @$list);
    die "No item found\n" unless scalar @$list;

    # ループで iCal フォーマットを作成
    my $calyear = (localtime)[5] + 1900;
    my $out = [];
    push(@$out, "BEGIN:VCALENDAR\n");
    push(@$out, "VERSION:2.0\n");
    foreach my $array (@$list) {
        my($year, $mon, $day, $name, $link) = @$array;
        my $title = $name." (".$year."年)";
        my $date = sprintf("%04d%02d%02d", $calyear, $mon, $day);
        info($date, $title);
        push(@$out, "BEGIN:VEVENT\n");
        push(@$out, "DTSTART;VALUE=DATE:$date\n");
        push(@$out, "DTEND;VALUE=DATE:$date\n");
        push(@$out, "SUMMARY:$title\n");
        push(@$out, "DESCRIPTION:$link\n") if $link;
        push(@$out, "STATUS:CONFIRMED\n");
        push(@$out, "CLASS:PUBLIC\n");
        push(@$out, "END:VEVENT\n");
    }
    push(@$out, "END:VCALENDAR\n");
    
    # iCal ファイルに保存する
    save($file, $out);
}

# イベントを絞り込む
# grep１行で書けそうだけど、分かりやすく
sub event_grep {
    my $src = shift;
    my $regex = shift;
    my $dst = [];

    foreach my $array (@$src) {
        my($eyear, $mon, $day, $name, $link) = @$array;
        next unless ($name =~ $regex);
        push(@$dst, $array);
    }
    $dst;
}

# イベントを時系列でソートする
sub event_sort {
    my $src = shift;
    my $dst = [sort {$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2]} @$src];
    $dst;
}

# 重複したイベントを省く
sub event_uniq {
    my $src = shift;
    my $dst = [];
    my $chk = {};
    foreach my $array (@$src) {
        my($year, $mon, $day, $name, $link) = @$array;
        next if $chk->{$link} ++;
        push(@$dst, $array);
    }
    $dst;
}

# キャッシュ付きで Wikipedia のカレンダーページを取り出す
sub read_wikipedia {
    # キャッシュ JSON ファイルを読み込む
    my $json = load($CACHE_FILE) if (-f $CACHE_FILE);
    my $list = JSON->new->decode($json) if $json;

    # キャッシュがヒットしなかった場合
    unless (ref $list) {
        $list = parse_wikipedia();
        # キャッシュ JSON ファイルを書きこむ
        $json = JSON->new->encode($list) or die "JSON encode failed\n";
        save($CACHE_FILE, $json);
    }
    $list;
}

# キャッシュなしで Wikipedia のカレンダーページを取り出す
sub parse_wikipedia {
    # 今年の1月1日を取り出す
    my $year = (localtime)[5];
    my $time = timelocal(0,0,0,1,0,$year);
    my $buf = [];

    # 次の年の1月1日までループする
    while(1) {
        my($day, $mon, $ychk) = (localtime($time))[3..5];
        last if ($year != $ychk);
        $time += 24 * 3600;
        my $list = date_wikipedia($mon+1, $day);
        push(@$buf, @$list);
    }
    
    $buf;
}

# wikipedia の日付ごとのページを取り出してパースする
sub date_wikipedia {
    my $mon = shift;
    my $day = shift;
    my $query = sprintf("%d月%d日", $mon, $day);
    
    # Wikipedia のページ(HTML)を取り出す
    my $url = $WIKIPEDIA_QUERY . $query;
    my $html = fetch($url);
    utf8::decode($html);
    
    # 「できごと」の範囲のみを取り出す
    $html =~ s/$FORWARD_ERASER// or die "begin eraser failed\n";
    $html =~ s/$BACKWARD_ERASER// or die "rest eraser failed\n";

    # HTML をパースする
    my $tree = XML::TreePP->new(%$TREEPP_OPT)->parse($html);
    my $uls = $tree->{ul} or die "ul not found\n";
    my $list = [];
    foreach my $ul (@$uls) {
        my $lis = $ul->{li} or die "li not found\n";
        foreach my $li (@$lis) {
            next unless ref $li;
            my $as = $li->{'a'} or next;
            
            # <li> の行頭の「2011年」等を取り出す
            my $text = $li->{'#text'};
            my $year = ($text =~ m#^(\d+)年#)[0] if $text;
            
            #「2011年」がリンクになっている場合に対応する
            if (! $year) { 
                foreach my $a (@$as) {
                    $text = $a->{'#text'} or next;
                    $year = ($text =~ m#^(\d+)年#)[0] or next;
                    %$a = ();
                    last;
                }
            }
            next unless $year;
            
            # 年は整数値とする
            $year = $year - 0;
            
            # 年月日が特定できたので、<li> 内の全てのリンクを抽出する
            foreach my $a (@$as) {
                $text = $a->{'#text'} or next;
                my $link = $a->{'-href'};
                $link = $WIKIPEDIA_TOP.$link if ($link !~ /^http:/);
                $text =~ s/[（\(]($year)年[\)）]//;
                $text =~ s/^($year)年//;
                push(@$list, [$year, $mon, $day, $text, $link]);
            }
        }
    }
    $list;
}
