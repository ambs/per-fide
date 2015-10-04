 
function expand_entry(image) {
    var id = image.attr('id');
    var tid = id.replace("btst","st");
    var pid = id.replace("btst","prob");

    if (image.attr('src').match("arrow_in")) {
        image.attr('src', image.attr('src').replace("_in","_out"));
        $("#"+tid).hide(300);
        $("#"+pid).removeClass("rotate90");
    } else {
        image.attr('src', image.attr('src').replace("_out","_in"));
        $("#"+tid).show(300);
        $("#"+pid).addClass("rotate90");
    }
}

function my_trim(txt) {
    return txt.replace(/^\s*/, "").replace(/\s*$/, "");
}

function rtrim ( str, charlist ) {
    charlist = !charlist ? ' \\s\u00A0' : (charlist+'').replace(/([\[\]\(\)\.\?\/\*\{\}\+\$\^\:])/g, '\\$1');
    var re = new RegExp('[' + charlist + ']+$', 'g');    
    return (str+'').replace(re, '');
}

function get_selection() {
    var t = "";
    if (window.getSelection) {
        t = window.getSelection();
    } else if (document.getSelection) {
        t = document.getSelection();
    } else if(document.selection) {
        t = document.selection.createRange();
        t.expand("word");
        t=t.text;
    }
    t = rtrim(t);
    return t; //escape(t);
}

//     if (parseInt(navigator.appVersion)>=4)
//         if (navigator.userAgent.indexOf("MSIE")>0) { //IE 4+
//             var sel=document.selection.createRange();
//             sel.expand("word");
//             return escape(sel.text)
//         } else // NS4+
//             return escape(document.getSelection())
// }

function selected_word(div, direction) {
    var word = get_selection();
    var url;
    if (direction == 'st')
      url = uri_base+"ptd/"+div.attr('cid')+"/"+div.attr("slang")+"/"+div.attr('tlang')+"/"+word;
    else
      url = uri_base+"ptd/"+div.attr('cid')+"/"+div.attr("tlang")+"/"+div.attr('slang')+"/"+word;
    window.location = url;
}

$(document).ready(function() {
    $('input[type="text"]').keypress(function(event) {
        if (event.which == '13') {
            event.preventDefault();
        }});
    $('.match_left').dblclick(  function() {  selected_word($(this), 'st');  });
    $('.match_right').dblclick( function() {  selected_word($(this), 'ts');  });
    $('img[id^="btst"]').click( function() {   expand_entry($(this)); } );
    $('img[id^="btst"]').click();
});


