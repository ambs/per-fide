
function closeMenu() {
	$("#realMenu").css('display','none');
	$("#primaryContent").css('margin','0 0 0 2em');
	$("#showButton").css('display','');
	$("#closeButton").css('display','none');
	$("#menuContent").css('padding-left','10px');
}

function showMenu() {
	$("#realMenu").css('display','');
	$("#primaryContent").css('margin','0 0 0 18em');
	$("#showButton").css('display','none');
	$("#closeButton").css('display','');
	$("#menuContent").css('padding-left','1.5em');
}

function closeHorMenu() {
   $("#realMenu").css('display','none');
	$("#primaryContent_h").css('margin','0.5em 0 0 0');
	$("#content").css('padding-top','1em');
   $("#showHorButton").css('display','');
   $("#closeHorButton").css('display','none');
}

function showHorMenu() {
   $("#realMenu").css('display','');
	$("#primaryContent_h").css('margin','0 0 0 0');
	$("#content").css('padding-top','1em');
	$(".match_left").addClass("match_left_h");
	$(".match_left").removeClass("match_left");
   $("#showHorButton").css('display','none');
   $("#closeHorButton").css('display','');
}

function showHH() {
   $(".match_left").addClass('match_left_h');
   $(".match_left").removeClass('match_left');
   $(".match_right").addClass('match_right_h');
   $(".match_right").removeClass('match_right');
   $("#b_showHH").css('display','none');
   $("#b_showVV").css('display','');
}

function showVV() {
   $(".match_left_h").addClass('match_left');
   $(".match_left_h").removeClass('match_left_h');
   $(".match_right_h").addClass('match_right');
   $(".match_right_h").removeClass('match_right_h');
   $("#b_showHH").css('display','');
   $("#b_showVV").css('display','none');
}

function show(id) {
   var div = document.getElementById(id);

   if (div.style.display == '')
      div.style.display = 'none';
   else
      div.style.display = '';
}
