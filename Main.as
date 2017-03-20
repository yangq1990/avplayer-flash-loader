package 
{
	import flash.system.Security;
	import flash.display.MovieClip;
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	import flash.net.URLRequestMethod;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.display.Loader;
	import flash.events.EventDispatcher;
	import flash.system.LoaderContext;
	import flash.system.ApplicationDomain;
	import flash.display.DisplayObject;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	import flash.external.ExternalInterface;
	import flash.display.StageScaleMode;
	import flash.display.StageAlign;
	import fl.transitions.Tween;
	import fl.transitions.easing.Regular;
	import fl.transitions.TweenEvent;
	import flash.net.navigateToURL;
	import flash.events.TextEvent;
	import LoaderErrorCode;
	import flash.net.URLLoader;
	import flash.system.SecurityDomain;
	
	/*
	* avplayer-flash loader
	* @author yangq
	*/
	public class Main extends MovieClip
	{
		private var _errorCode:uint; //错误代码
		private var _loader:Loader;		
		private var _timeout:uint;		
		private var _tween:Tween;
	
		public function Main()
		{
			stage ? init() : addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);		
		}
		
		private function onAddedToStage(evt:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);	
			init();
		}
		
		private function init():void
		{
			Security.allowDomain("*");
			Security.allowInsecureDomain("*");
			stage.color = 0x000000;
			stage.frameRate = 30;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			var w:int = stage.stageWidth;
			var h:int = stage.stageHeight;
			
			//调整位置，默认不可见
			_error_mc.x = w * 0.5;
			_error_mc.y = h * 0.5 - 25;
			
			//默认可见
			_loading_mc.x = w * 0.5;
			_loading_mc.y = (h - 40) * 0.5;
			
			loadAVPlayer();
		}
		
		/** 加载播放器swf **/
		private function loadAVPlayer():void
		{
			_loader = new Loader();
			_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadSwfComplete);
			_loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadSwfIOError);
			_loader.contentLoaderInfo.sharedEvents.addEventListener("removeLoading", onRemoveLoading);				
			var context:LoaderContext = new LoaderContext(); //不检查策略文件
			context.applicationDomain = new ApplicationDomain(); //加载到新域(独立运行)
			context.securityDomain = SecurityDomain.currentDomain; //加载到当前的安全域
			//通常，通过分析请求 URL 来获得 contentLoaderInfo.parameters 属性的值。
			//如果设置了 parameters 变量，则 contentLoaderInfo.parameters 从 LoaderContext 对象而不是从请求 URL 中获取其值。
			context.parameters = {};
			for(var item:* in stage.loaderInfo.parameters) //复制参数，否则AVPlayer收不到
			{
				context.parameters[item] = stage.loaderInfo.parameters[item];
			}
			//context.parameters的key-value, value必须为字符串，否则会触发IllegalOperationError:LoaderContext.parameters 参数设置为非 null，并且具有不是字符串的某些值
			context.parameters["skinUrl"] = "./flash/skin.swf";	
			var req:URLRequest = new URLRequest('./flash/avplayer.swf');			
			_loader.load(req, context);
		}
		
		/** 加载播放器出错 **/
		private function onLoadSwfIOError(evt:IOErrorEvent):void
		{
			if(_loader)
			{
				_loader.unloadAndStop();
				removeLoaderListeners();
				_loader = null;
			}
			_errorCode = LoaderErrorCode.EC_1001;
			startTween();
		}
		
		/** 加载播放器complete **/
		private function onLoadSwfComplete(evt:Event):void
		{
			removeLoaderListeners();			
			try
			{
				_loader.content.addEventListener(Event.ADDED_TO_STAGE, onContentAddedToStage);			
				addChildAt(_loader.content, 0);
			}
			catch(err:SecurityError)
			{
				_errorCode = LoaderErrorCode.EC_1002;
				startTween();
			}			
		}	
		
		private function onContentAddedToStage(evt:Event):void
		{
			_loader.content.removeEventListener(Event.ADDED_TO_STAGE, onContentAddedToStage);
		}
		
		//收到AVPlayer.swf发来的事件，remove loading 
		private function onRemoveLoading(evt:Event):void
		{
			_loader.contentLoaderInfo.sharedEvents.removeEventListener("removeLoading", onRemoveLoading);		
			_timeout = setTimeout(removeLoading, 50); //50ms后remove loading, 为了避免网速太快时一闪而过
		}		
		
		private function removeLoading():void
		{			
			if(_loading_mc)
			{
				_loading_mc.addEventListener(Event.REMOVED_FROM_STAGE, onLoadingRemoveFromStage);
				_loading_mc.visible = false;
				removeChild(_loading_mc);		
			}			
				
			if(_error_mc)
			{
				removeChild(_error_mc);
			}
			
			if(_timeout)
			{
				clearTimeout(_timeout);
				_timeout = undefined;
			}						
		}
		
		//loading被移除舞台
		private function onLoadingRemoveFromStage(evt:Event):void
		{
			_loading_mc && (_loading_mc = null);
			_error_mc && (_error_mc = null);
			
			//通知avplayer.swf显示界面
			_loader.contentLoaderInfo.sharedEvents.dispatchEvent(new Event("loadingRemoved"));
		}
		
		private function removeLoaderListeners():void
		{
			if(_loader)
			{
				_loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onLoadSwfComplete);
				_loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSwfIOError);
			}
		}
		
		private function startTween():void
		{
			if(_tween == null)
			{
				if(_loading_mc)
				{
					_loading_mc.parent.removeChild(_loading_mc);
					_loading_mc = null;
				}					
			
				_error_mc.errorCodeTxt.text = _errorCode.toString();
				_error_mc.visible = true;
				_tween = new Tween(_error_mc, "alpha", Regular.easeIn,  0, 1, 0.8, true);
				_tween.addEventListener(TweenEvent.MOTION_FINISH, onMotionFinish);
				_tween.start();
			}			
		}
		
		private function onMotionFinish(evt:TweenEvent):void
		{
			_tween.removeEventListener(TweenEvent.MOTION_FINISH, onMotionFinish);
			_tween = null;			
		}
	}
}