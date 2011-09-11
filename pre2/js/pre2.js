// pre2.js

var theMap;
var theCal;
var LISTURL = 'data/list.json';
var DESCURL = 'data/desc.json';
var cacheList;
var cacheMap;
var cacheCell;
var cellToIndex = [];
var indexToCell = [];
var cacheDesc;
var bufCircle = [];
var WDAY = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
var ONEDAY = 24 * 3600 * 1000;
var MONNAME = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
var MAGCOLOR = ['#666666', '#FF9', '#FD8', '#FB7', '#F96', '#F75', '#F54', '#F33', '#F12', '#F00', '#C00'];

function showCalendar() {
    var daymap = [];
    var i;
    for(i=0; i<cacheList.length; i++) {
        var item = cacheList[i];
        var split = item.date.split(/-/);
        var mon = split[1]-0;
        var day = split[2]-0;
        if (! mon || ! day) {
            continue;
        }
        var key = mon+'/'+day;
        if (! daymap[key]) {
            daymap[key] = [];
        }
        daymap[key].push(item);
    }
    cacheMap = daymap;
    cacheCell = [];

    var table = $('<table/>');
    var tr = $('<tr/>');
    var thead = $('<thead/>').append(tr);
    table.append(thead);
    for(i=0; i<7; i++) {
        var th = $('<th/>').text(WDAY[i]);
        tr.append(th);
    }

    var tbody = $('<tbody/>');
    table.append(tbody);
    var thisyear = (new Date()).getFullYear();
    var date = new Date(thisyear, 0, 1);
    var wday = date.getDay(); // 0:Sun, 6:Sat
    var time = date.getTime();
    wday = (wday + 6) % 7;
    date.setTime(time - wday * ONEDAY);
    var prev;
    var year;
    while (1) {
        tr = $('<tr/>');
        for(i=0; i<7; i++) {

            // DAY
            var day = date.getDate();
            var mon = date.getMonth();
            var vday = day;
            if (mon != prev) {
                vday = MONNAME[mon] + ' ' + day;
            }
            var h4 = $('<h4/>').text(vday);
            if (date.getDay() % 6 == 0) {
                h4.addClass('weekend');
            }
            var td = $('<td/>').append(h4);
            tr.append(td);
            prev = mon;
            year = date.getFullYear();
            if (year != thisyear) {
                td.addClass('anotheryear');
            }

            // EVENTS
            var key = (mon+1)+'/'+day;
            var list = daymap[key];
            if (year == thisyear) {
                cacheCell[key] = td;
                var idx = indexToCell.length;
                cellToIndex[key] = idx;
                indexToCell[idx] = key;
                td.data('key', key);
                td.click(onClickCell);
            }
            if (list && year == thisyear) {
                var ul = $('<ul/>');
                for(var j=0; j<list.length; j++) {
                    var item = list[j];
                    var li = $('<li/>').text(item.name);
                    ul.append(li);
                }
                td.append(ul);
            }

            date.setTime(date.getTime() + ONEDAY);
        }
        tbody.append(tr);
        year = date.getFullYear();
        if (year > thisyear) {
            break;
        }
    }
    theCal = $('#calhere');
    theCal.append(table);
    showControler();
}

function showControler() {
    var div = $('<div/>');
    var btn1 = $('<button/>').text('←').click(onClickPrev);
    var btn2 = $('<button/>').text('→').click(onClickNext);
    var btn3 = $('<button/>').text('AUTO').click(onClickAuto);
    var btn4 = $('<button/>').text('STOP').click(onClickStop);
    var btn5 = $('<button/>').text('TODAY').click(onClickToday);
    div.append(btn1);
    div.append(btn2);
    div.append(btn3);
    div.append(btn4);
    div.append(btn5);
    $('#ctrlhere').append(div);
}

var timerId;
function onClickAuto() {
    if (timerId) return;
    timerId = -1;
    autoPlay();
}

function onClickToday() {
    onClickStop();
    var date = new Date();
    var mon = date.getMonth()+1;
    var day = date.getDate();
    var key = mon+'/'+day;
    selectDay(key);
}

function autoPlay() {
    if (! timerId) return;
    timerId = null;
    var idx = moveCursor(+1); 
    if (! idx) return;
    timerId = setTimeout(autoPlay, 100);
}

function onClickStop() {
    if (! timerId) return;
    clearTimeout(timerId);
    timerId = null;
}

function onClickPrev() {
    onClickStop();
    moveCursor(-1);
}

function onClickNext() {
    onClickStop();
    moveCursor(+1);
}

function moveCursor(offset) {
    var key = $('td.today').data('key');
    var idx = key ? cellToIndex[key] : -offset;
    var newidx = idx + offset;
    console.log(key, idx+'+'+offset+'='+newidx);
    if (newidx < 0) return;
    if (newidx > indexToCell.length-1) return;
    var newkey = indexToCell[newidx];
    if (!newkey) return;
    selectDay(newkey);
    return newidx-idx;
}

function onClickCell(aa,bb) {
    var key = $(this).data('key');
    if (!key) return;
    selectDay(key);
}

function selectDay(key) {
    $('#calhere td.today').removeClass('today');
    var td = cacheCell[key];
    if (!td) return;
    td.addClass('today');
    td.focus();
    var list = cacheMap[key];
    if (!list) return;
    var i;
    for(i=0; i<bufCircle.length; i++) {
        var circle = bufCircle[i];
        circle.setMap(null);
    }
    bufCircle = [];

    var top = td.position().top - theCal.position().top;
    if (top < 0) {
        theCal.animate({scrollTop: (theCal.scrollTop() + top)}, 100);
    } else if (top > theCal.height()) { 
        theCal.animate({scrollTop: (theCal.scrollTop() + top - theCal.height() + td.height())}, 100);
    }

    for(i=0; i<list.length; i++) {
        var item = list[i];
        var lat = item.lat;
        var lng = item.lng;
        if (!lat) continue;
        if (!lng) continue;
        
        var center = new google.maps.LatLng(lat, lng);
        var mag = Math.floor(item.mag);
        var color = MAGCOLOR[mag] || '#666';
//  google.maps.event.addListener(map, 'click', addLatLng);

        var circle = new google.maps.Circle({
        center: center,       // 中心点(google.maps.LatLng)
        fillColor: color,   // 塗りつぶし色
        fillOpacity: 0.5,       // 塗りつぶし透過度（0: 透明 ⇔ 1:不透明）
        map: theMap,            // 表示させる地図（google.maps.Map）
        radius: 100000+50000*mag,          // 半径（ｍ）
        strokeColor: color, // 外周色 
        strokeOpacity: 1,       // 外周透過度（0: 透明 ⇔ 1:不透明）
        strokeWeight: 2         // 外周太さ（ピクセル）
        });
        bufCircle.push(circle);
    };
}

function onLoadDesc (data) {
    var hash = {};
    for(var i=0; i<data.length; i++) {
        var item = data[i];
        hash[item.link] = item;
    }
    cacheDesc = hash;
    // console.log(data);
    showCalendar();
}

function onLoadList (data) {
    // console.log(data);
    cacheList = data;
    $.getJSON(DESCURL, onLoadDesc);
}

function showMap () {
    var myLatLng = new google.maps.LatLng(10, 20);
    theMap = new google.maps.Map(document.getElementById('maphere'), {
        zoom: 2,
        center: myLatLng,
        // mapTypeId: google.maps.MapTypeId.SATELLITE,
        mapTypeId: google.maps.MapTypeId.TERRAIN,
        scaleControl: false,
        scrollwheel: false
    });
}

function init () {
    $.getJSON(LISTURL, onLoadList);
    setTimeout(showMap, 1);
}

$(init);
