package org.bigbluebutton.modules.videoconf.views
{
  import com.asfusion.mate.events.Dispatcher;
  
  import flash.events.AsyncErrorEvent;
  import flash.events.NetStatusEvent;
  import flash.filters.ConvolutionFilter;
  import flash.net.NetConnection;
  import flash.net.NetStream;
  
  import org.as3commons.logging.api.ILogger;
  import org.as3commons.logging.api.getClassLogger;
  import org.bigbluebutton.core.BBB;
  import org.bigbluebutton.core.UsersUtil;
  import org.bigbluebutton.core.model.LiveMeeting;
  import org.bigbluebutton.core.model.VideoProfile;
  import org.bigbluebutton.main.events.BBBEvent;
  import org.bigbluebutton.main.events.StartedViewingWebcamEvent;
  import org.bigbluebutton.main.events.StoppedViewingWebcamEvent;
  import org.bigbluebutton.main.views.VideoWithWarnings;
  import org.bigbluebutton.modules.videoconf.events.StartBroadcastEvent;
  import org.bigbluebutton.modules.videoconf.events.StopBroadcastEvent;
 // Kaaryin changes for Streamed View 
  import flash.media.SoundTransform;
  // END //
  public class UserVideo extends UserGraphic {
	private static const LOGGER:ILogger = getClassLogger(UserVideo);      

    protected var _camIndex:int = -1;

    protected var _ns:NetStream;

    protected var _shuttingDown:Boolean = false;
    protected var _streamName:String;
    protected var _video:VideoWithWarnings = null;
    protected var _videoProfile:VideoProfile;
    protected var _dispatcher:Dispatcher = new Dispatcher();
// Kaaryin changes for Streamed View	
	private var STREAMING_URL:String;
	private var videoURL:String;
	private var streamID:String;
	private var connection_temp:NetConnection;
// END //	
    public function UserVideo() {
      super();

      _video = new VideoWithWarnings();
      _background.addChild(_video);
    }

    public function publish(camIndex:int, videoProfile:VideoProfile, streamName:String):void {
      if (_shuttingDown) {
        var logData:Object = UsersUtil.initLogData();
        logData.streamName = streamName;
        logData.tags = ["video"];
        logData.message = "Method publish called while shutting down the video window, ignoring...";
        LOGGER.warn(JSON.stringify(logData));
        return;
      }

      _camIndex = camIndex;
      _videoProfile = videoProfile;
      _streamName = streamName;
      setOriginalDimensions(_videoProfile.width, _videoProfile.height);

      _video.updateCamera(camIndex, _videoProfile, _background.width, _background.height);
      
      invalidateDisplayList();
      startPublishing();
    }

    public static function newStreamName(userId:String, profile:VideoProfile):String {
      /**
       * Add timestamp to create a unique stream name. This way we can record   
       * stream without overwriting previously recorded streams.    
       */   
      var d:Date = new Date();
      var curTime:Number = d.getTime(); 
      var streamId: String = profile.id + "-" + userId + "-" + curTime;
       if (UsersUtil.isRecorded()) {
          // Append recorded to stream name to tell server to record this stream.
          // ralam (feb 27, 2017)
          streamId += "-recorded";
        }
        
        return streamId;
    }

    public static function getVideoProfile(stream:String):VideoProfile {
      LOGGER.debug("Parsing stream name [{0}]", [stream]);
      var pattern:RegExp = new RegExp("([A-Za-z0-9]+)-([A-Za-z0-9_]+)-\\d+", "");
      if (pattern.test(stream)) {
        LOGGER.debug("The stream name is well formatted");
        LOGGER.debug("Video profile resolution is [{0}]", [pattern.exec(stream)[1]]);
        LOGGER.debug("Userid [{0}]", [pattern.exec(stream)[2]]);
        return BBB.getVideoProfileById(pattern.exec(stream)[1]);
      } else {
        LOGGER.debug("Bad stream name format");
        var profile:VideoProfile = BBB.defaultVideoProfile;
        if (profile == null) {
          profile = BBB.fallbackVideoProfile;
        }
        return profile;
      }
    }

    private function startPublishing():void {
      _shuttingDown = false;

      var e:StartBroadcastEvent = new StartBroadcastEvent();
      e.stream = _streamName;
      e.camera = _video.getCamera();
      e.videoProfile = _videoProfile;
      _dispatcher.dispatchEvent(e);
    }

    public function shutdown():void {
      if (!_shuttingDown) {
        _shuttingDown = true;
        if (_ns) {
          stopViewing();
          _ns.close();
          _ns = null;
        }

        if (_video.cameraState()) {
            stopPublishing();
        }

        if (_video) {
            _video.disableCamera();
        }
      }
    }

    private function stopViewing():void {
        // Store that I stopped viewing this streamId;
        var myUserId: String = UsersUtil.getMyUserID();
        LiveMeeting.inst().webcams.stoppedViewingStream(myUserId, _streamName);
        
      var stopEvent:StoppedViewingWebcamEvent = new StoppedViewingWebcamEvent();
      stopEvent.webcamUserID = user.intId;
      stopEvent.streamName = _streamName;
      _dispatcher.dispatchEvent(stopEvent); 
      
    }

    private function startedViewing():void {
        // Store that I started viewing this streamId;
        var myUserId: String = UsersUtil.getMyUserID();
        LiveMeeting.inst().webcams.startedViewingStream(myUserId, _streamName);
        
        var startEvent:StartedViewingWebcamEvent = new StartedViewingWebcamEvent();
        startEvent.webcamUserID = user.intId;
        startEvent.streamName = _streamName;
        _dispatcher.dispatchEvent(startEvent); 
        
    }
    
    private function stopPublishing():void {
      var e:StopBroadcastEvent = new StopBroadcastEvent();
      e.stream = _streamName;
      e.camId = _camIndex;
      _dispatcher.dispatchEvent(e);
    }

    public function view(connection:NetConnection, streamName:String):void {
      if (_shuttingDown) {
        var logData:Object = UsersUtil.initLogData();
        logData.streamName = streamName;
        logData.tags = ["video"];
        logData.message = "Method view called while shutting down the video window, ignoring...";
        LOGGER.warn(JSON.stringify(logData));
// Kaaryin changes for Streamed View		
		stopViewing();
        //_ns.close();
		_ns.receiveAudio(false);
        _video.disableCamera();
// END //
        return;
      }

      _streamName = streamName;
      _shuttingDown = false;

      _ns = new NetStream(connection);
      _ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
      _ns.addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
      _ns.client = this;
      _ns.bufferTime = 0;
      _ns.receiveVideo(true);
      _ns.receiveAudio(false);
      
      _videoProfile = UserVideo.getVideoProfile(streamName);
      LOGGER.debug("Remote video profile: {0}", [_videoProfile.toString()]);
      if (_videoProfile == null) {
        throw("Invalid video profile");
        return;
      }
      setOriginalDimensions(_videoProfile.width, _videoProfile.height);

      _video.attachNetStream(_ns, _videoProfile, _background.width, _background.height);
      
      if (options.applyConvolutionFilter) {
        var filter:ConvolutionFilter = new ConvolutionFilter();
        filter.matrixX = 3;
        filter.matrixY = 3;
        LOGGER.debug("Applying convolution filter =[{0}]", [options.convolutionFilter]);
        filter.matrix = options.convolutionFilter;
        filter.bias =  options.filterBias;
        filter.divisor = options.filterDivisor;
        _video.videoFilters([filter]);
      }
// Kaaryin changes for Streamed View  
		// _ns.play(streamName);
			STREAMING_URL = BBB.getConfigManager().config.help['url']
			var tempURL:Array = STREAMING_URL.split("-");
			videoURL = String(tempURL[0]);
			streamID = String(tempURL[1]);

		//if(user.presenter){
		if(_videoProfile.id == "low"){

			connection_temp = new NetConnection();
			connection_temp.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
			connection_temp.connect(videoURL);
		}else{
			_ns.play(streamName);
		}
// END //		
      startedViewing();
      
      invalidateDisplayList();
    }
	
// Kaaryin changes for Streamed View  	
	private function onConnectionStatus(e:NetStatusEvent):void{
		if (e.info.code == "NetConnection.Connect.Success")
			{
					_ns = new NetStream(connection_temp);
					_video.attachNetStream(_ns,_videoProfile, _background.width, _background.height);
					_ns.play(streamID);
					
			}
	}
	public function disableSound():void
	{
	
		var newSoundTransform:SoundTransform=new SoundTransform();
		newSoundTransform.volume=0;
		_ns.soundTransform=newSoundTransform;
		
	}
// END //
    private function onNetStatus(e:NetStatusEvent):void{
      switch(e.info.code){
        case "NetStream.Publish.Start":
          LOGGER.debug("NetStream.Publish.Start for broadcast stream {0}", [_streamName]);
          break;
        case "NetStream.Play.UnpublishNotify":
          shutdown();
          break;
        case "NetStream.Play.Start":
			LOGGER.debug("Netstatus: {0}", [e.info.code ]);
          _dispatcher.dispatchEvent(new BBBEvent(BBBEvent.VIDEO_STARTED));
          break;
        case "NetStream.Play.FileStructureInvalid":
		  LOGGER.error("The MP4's file structure is invalid.");
          break;
        case "NetStream.Play.NoSupportedTrackFound":
		  LOGGER.error("The MP4 doesn't contain any supported tracks");
          break;
      }
    }

    private function onAsyncError(e:AsyncErrorEvent):void{
		LOGGER.debug(e.text);
    }
    
    private function onMetaData(info:Object):void {
		LOGGER.debug("width={0} height={1}", [info.width, info.height]);
    }

    override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void {
        super.updateDisplayList(unscaledWidth, unscaledHeight);

        updateDisplayListHelper(unscaledWidth, unscaledHeight, _video);
    }

     public function get camIndex():int {
      return _camIndex;
    }

     public function get streamName():String {
      return _streamName;
    }
  }
}
