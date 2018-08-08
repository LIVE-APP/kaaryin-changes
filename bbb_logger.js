var kaaryinClients = [];
kaaryinClients[0] = "https://kaaryin.com/";
kaaryinClients[1] = "http://local.kaaryin.com/";
kaaryinClients[2] = "http://sollers.kaaryin.com/sollers/web/";
kaaryinClients[3] = "http://asianet.kaaryin.com/asianet/web/";
kaaryinClients[4] = "http://maalee.kaaryin.com/maalee/web/";
kaaryinClients[5] = "https://courses.live-tutor.com/";
kaaryinClients[6] = "http://asianet.live-tutor.com/asianet/courses/";
kaaryinClients[7] = "http://myconf.live-tutor.com/";
kaaryinClients[9] = "http://livetutoredu.com/";
kaaryinClients[10] = "http://tia.kaaryin.com/";
$(window).load(function(){
	$.ajax({
		method: "GET",
		url: '/bigbluebutton/api/enter' + document.location.search,
		dataType: "json",		
	}).done(function(response) {
		console.log(response);
		initLTActions(response.response);
	})  
	.fail(function() {
		//console.log( "error" );
	})
	.always(function() {
		//console.log( "complete" );
	});
});
(function(window, undefined) {

    var BBBLog = {};

    BBBLog.critical = function (message, data) {
      console.log(message, JSON.stringify(data));
    }
    
    BBBLog.error = function (message, data) {
      console.log(message, JSON.stringify(data));
    }

    BBBLog.warning = function (message, data) {
      console.log(message, JSON.stringify(data));
    }
    
    BBBLog.info = function (message, data) {
      console.log(message, JSON.stringify(data));
    }
    
    BBBLog.debug = function (message, data) {
      console.log(message, JSON.stringify(data));
    }
    
    window.BBBLog = BBBLog;
})(this);

function initLTActions(data){
	var myRole = data.role;
	if(myRole == 'MODERATOR'){
		$('#liveclassEndButton').closest('div').show();
	}	
	var kaaryinMeetingId = data.externMeetingID;
	console.log(kaaryinMeetingId);
	kaaryinMeetingIdSplit = kaaryinMeetingId.split('-');
	var kaaryinClientId = Number(kaaryinMeetingIdSplit[kaaryinMeetingIdSplit.length - 1]);
	window.siteRoot = isNaN(kaaryinClientId)?kaaryinClients[0]:kaaryinClients[kaaryinClientId];
	var userName = (data.hasOwnProperty('fullname'))?(data.fullname):"user-fullname";
	$('#serverCustomStyleSheet').attr('href', siteRoot+"/css/custom.css");
	$('#serverStyleSheet').attr('href', siteRoot+"/css/style.css");
	window.endMeetingUrl = siteRoot+"live-class/end/"+kaaryinMeetingId;
	$('#headerUserName').html('Welcome, '+userName);
	setHostLinks();
}
function showHeader(response){
	var headerHtml = response.headerHtml;
	var layoutPrefix = response.LAYOUT_PREFIX;
	headerHtml += '<link href="'+window.siteRoot+'/css/'+layoutPrefix+'custom.css" rel="stylesheet">';	
	$( "header" ).replaceWith(headerHtml);
}
function setHostLinks(){
	siteRoot = window.siteRoot;
	$.ajax({
		method: "GET",
		url: siteRoot+"get-site-header-html",
		dataType: "jsonp",
		jsonpCallback: "showHeader"		
	});
}
function endMeeting(){
	if(confirm('This action will end this live-session & exit all the participants from it. Do you really want to proceed?')){
		window.location.href = window.endMeetingUrl;
	}
	else{
		return false;
	}
}	
