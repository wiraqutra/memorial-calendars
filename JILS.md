2011/08/06 [Japan Innovation Leaders Summit](http://rikunabi-next.yahoo.co.jp/tech/docs/ct_s04510.jsp?p=techacademy) 会場で MIT 石井教授のトークを受けて、#JILS の会場でプロトタイプ版を作成してみました。

Wikipedia を参照して、過去に発生した地震の日付を Google カレンダーに表示します。

関心のある方は、[Hack For Japan](http://www.hack4.jp/) メーリングリスト経由でぜひご協力ください！#hack4jp

### Prototype on Google Calendar ###
  * http://bit.ly/eqcal ← ここからプロトタイプ版を確認できます

### Prorotype iCal ###
  * http://memorial-calendars.googlecode.com/svn/trunk/prototype/out/eq.ics

### Prorotype Source ###
  * http://memorial-calendars.googlecode.com/svn/trunk/prototype/

### TODO ###
  * Wikipedia のリンク情報のみを利用しているため、実際の地震発生日以外の日付が載ってしまう場合があります。
  * 地震に限れば、ソースは [地震の年表](http://ja.wikipedia.org/wiki/地震の年表) の方が良さそう。データソース要検討。
  * キャッシュしてるけど、Wikipedia は1秒おきにアクセスしていいのでしょうか？API or 他のソース？
  * 今年1月〜12月のカレンダーに登録してるけど、来年は空になってる
  * iCal 形式でいいの？XML の方が使いやすそう
  * 現状の Google Calendar インポートは手動。自動更新する仕組みの実現方法が不明
  * ちゃんと MIT License を表記しないと
  * ロゴがほしい
  * HTML のパース処理が正規表現＋XML (XHTML) なので、イマイチ。（△メンテ性など）
  * 要は、最初から作り直す必要がある