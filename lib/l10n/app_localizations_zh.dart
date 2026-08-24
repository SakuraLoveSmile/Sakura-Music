// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '音流';

  @override
  String get viewSwitch => '视图切换';

  @override
  String get settings => '设置';

  @override
  String get welcomeTagline => '连接你的音乐';

  @override
  String get privacyPrefix => '继续使用即表示同意 ';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get addedTapCardHint => '已添加，点击卡片进入';

  @override
  String get featureMultiSource => '多源支持';

  @override
  String get featureMultiSourceDesc => '支持 Navidrome、Emby 等多种服务器协议';

  @override
  String get featureLossless => '无损播放';

  @override
  String get featureLosslessDesc => 'Hi-Res 音质';

  @override
  String get featureNative => '原生体验';

  @override
  String get featureNativeDesc => 'SwiftUI 构建';

  @override
  String get featureCrossPlatform => '全平台支持';

  @override
  String get featureCrossPlatformDesc => 'iOS、macOS、tvOS 无缝切换';

  @override
  String get search => '搜索';

  @override
  String get welcomeNav => '欢迎';

  @override
  String get serversSection => '服务器';

  @override
  String loadFailed(Object message) {
    return '加载失败：$message';
  }

  @override
  String get noServers => '暂无服务器';

  @override
  String get noSearchResults => '无符合结果';

  @override
  String get addServer => '新增服务器';

  @override
  String get more => '更多';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get chooseLibrary => '选择媒体库';

  @override
  String serverCount(int count) {
    return '共 $count 台服务器';
  }

  @override
  String get currentBadge => '当前';

  @override
  String get emptyPickerTitle => '还没有服务器';

  @override
  String get emptyPickerDesc => '添加你的第一台服务器，连接你的音乐';

  @override
  String get addFirstServer => '添加第一台服务器';

  @override
  String get editServer => '编辑服务器';

  @override
  String get close => '关闭';

  @override
  String get serverType => '服务器类型';

  @override
  String get serverName => '服务器名称';

  @override
  String get serverNameHint => '如：我的 Navidrome';

  @override
  String get pleaseInputServerName => '请输入服务器名称';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get hostLabel => '主机';

  @override
  String get pleaseInputServerAddress => '请输入服务器地址';

  @override
  String get hostNoScheme => '无需填写协议，请只输入主机';

  @override
  String get portInRightField => '端口请填写在端口输入框';

  @override
  String get portLabel => '端口';

  @override
  String get portRange => '1–65535';

  @override
  String get username => '账号 / 用户名';

  @override
  String get pleaseInputUsername => '请输入用户名';

  @override
  String get password => '密码';

  @override
  String get pleaseInputPassword => '请输入密码';

  @override
  String get connectSuccess => '连接成功！服务器通信正常。';

  @override
  String connectFailed(Object message) {
    return '连接失败：$message';
  }

  @override
  String saveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get testConnection => '测试连接';

  @override
  String get saveChanges => '保存修改';

  @override
  String get saveAndConnect => '保存并连接';

  @override
  String get deleteServerTitle => '删除服务器？';

  @override
  String deleteServerConfirm(Object name) {
    return '确定要删除「$name」吗？这只会移除本地保存的连接信息。';
  }

  @override
  String get cancel => '取消';

  @override
  String get back => '返回';

  @override
  String get switchLibrary => '切换音乐库';

  @override
  String get membership => '会员';

  @override
  String get membershipActivated => '已激活';

  @override
  String get activateMembership => '开通会员';

  @override
  String get activateMembershipSubtitle => '通过激活码或 Star 开源仓库即可激活全部会员权益';

  @override
  String get membershipActiveBannerTitle => '会员已激活';

  @override
  String get activationCodeTitle => '激活码激活';

  @override
  String get activationCodeHint => '请输入激活码';

  @override
  String get activateButton => '激活';

  @override
  String get activationSuccess => '激活成功，已开通会员功能！';

  @override
  String get activationCodeInvalid => '激活码无效，请检查后重试';

  @override
  String get starActivationTitle => 'Star 点亮激活';

  @override
  String get starActivationDesc =>
      '如果你已在 GitHub 上为本项目点亮 Star，可开启此开关直接激活。我们不做联网检测，请凭诚信开启。';

  @override
  String get goToStar => '前往 Star';

  @override
  String get activatedViaCode => '激活方式：激活码';

  @override
  String get activatedViaStar => '激活方式：Star 诚信激活';

  @override
  String get deactivateMembership => '取消激活';

  @override
  String get deactivatedSuccess => '已取消会员激活';

  @override
  String get notActivated => '未开通';

  @override
  String get sectionPlayback => '播放';

  @override
  String get autoPlayOnLaunch => '启动后自动播放';

  @override
  String get fadeTransition => '淡入淡出';

  @override
  String get musicRoaming => '音乐漫游';

  @override
  String get audiobooksPodcasts => '有声书/播客';

  @override
  String get streamingQuality => '在线播放音质';

  @override
  String get equalizerSettings => '均衡器设置';

  @override
  String get lyricsOverlay => '桌面悬浮歌词';

  @override
  String get lyricsOverlayPermissionNeeded => '需要悬浮窗权限，请在系统设置中授予后重试';

  @override
  String get sectionNetwork => '网络';

  @override
  String get backgroundDownload => '后台下载';

  @override
  String get downloadWifiOnly => '仅 Wi-Fi';

  @override
  String get downloadAnyNetwork => '所有网络';

  @override
  String get downloadOff => '关闭';

  @override
  String get networkProxy => '网络代理';

  @override
  String get sectionStorage => '存储与服务';

  @override
  String get serverManagement => '服务器管理';

  @override
  String get notConnected => '未连接';

  @override
  String get addNewServer => '添加新服务器';

  @override
  String get clearCache => '清除歌曲缓存';

  @override
  String get cacheCleared => '已清除本地临时缓存数据';

  @override
  String get sectionAppearance => '外观';

  @override
  String get language => '语言';

  @override
  String get sectionAbout => '关于';

  @override
  String get currentVersion => '当前版本';

  @override
  String get loading => '读取中…';

  @override
  String get unknown => '未知';

  @override
  String get checkUpdates => '检查更新';

  @override
  String get updateAvailable => '发现新版本';

  @override
  String get downloading => '下载中';

  @override
  String get downloaded => '已下载';

  @override
  String get installing => '安装中';

  @override
  String get retry => '重试';

  @override
  String get upToDate => '已是最新版本';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get qualityLosslessAuto => '无损 / 自动';

  @override
  String get qualityFlacWav => 'FLAC / WAV 极高音质';

  @override
  String get quality320 => '320 kbps MP3 高音质';

  @override
  String get quality192 => '192 kbps MP3 标准音质';

  @override
  String get quality128 => '128 kbps MP3 流畅节省流量';

  @override
  String get proxyDialogTitle => '网络代理设置';

  @override
  String get proxyAddressLabel => 'HTTP / SOCKS5 代理地址';

  @override
  String get proxySaved => '网络代理设置已保存';

  @override
  String get save => '保存';

  @override
  String get followSystem => '跟随系统';

  @override
  String get aboutSection => '简介';

  @override
  String get addLibraryFirst => '请先在服务器页添加一个音乐库。';

  @override
  String get addToQueue => '追加到队列';

  @override
  String addedToDownloads(Object title) {
    return '已添加「$title」至下载队列';
  }

  @override
  String addedToPlayNext(Object title) {
    return '已将「$title」添加到下一首播放';
  }

  @override
  String get addedToQueue => '已追加到队列';

  @override
  String get albumEmptyTracks => '这个专辑没有可播放的曲目。';

  @override
  String albumLoadFailed(Object error) {
    return '加载专辑详情失败：$error';
  }

  @override
  String albumsLoadFailed(Object error) {
    return '加载专辑失败：$error';
  }

  @override
  String get allAlbumsLoaded => '已加载全部专辑';

  @override
  String artistAlbumCount(int count) {
    return '$count 张专辑';
  }

  @override
  String artistsLoadFailed(Object error) {
    return '加载歌手失败：$error';
  }

  @override
  String assetInfo(Object name, Object size) {
    return '安装包：$name · $size';
  }

  @override
  String get browse => '浏览';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get cast => '投播';

  @override
  String get clear => '清空';

  @override
  String get clearHistory => '清空历史';

  @override
  String get collapsePlayer => '收起';

  @override
  String get connectedLibraries => '已连接的音乐库';

  @override
  String get dailyMixSubtitle => '根据你的收听偏好智能推荐';

  @override
  String get dailyMixTitle => '今日私享歌单';

  @override
  String get dailyRecommend => '每日推荐';

  @override
  String get deleteDownload => '删除下载';

  @override
  String get download => '下载';

  @override
  String get downloadSong => '下载歌曲';

  @override
  String downloadsLoadFailed(Object error) {
    return '读取下载失败：$error';
  }

  @override
  String get emptyAlbums => '服务器中还没有专辑。';

  @override
  String get emptyArtists => '服务器中还没有歌手。';

  @override
  String get emptyDownloads => '还没有下载歌曲。';

  @override
  String get emptyGenres => '音乐库中还没有流派信息';

  @override
  String get emptyLibrarySongs => '音乐库中还没有歌曲';

  @override
  String get emptyPlayerDesc => '从歌曲或专辑列表中选择一首歌曲开始播放。';

  @override
  String get emptyPlayerTitle => '还没有正在播放的歌曲';

  @override
  String get emptyPlaylists => '还没有歌单。';

  @override
  String get emptyQueue => '播放队列为空。';

  @override
  String get emptySearchHistory => '暂无搜索历史，输入关键词回车搜索。';

  @override
  String get enableEqualizer => '启用均衡器';

  @override
  String equalizerLoadFailed(Object error) {
    return '读取均衡器设置失败：$error';
  }

  @override
  String get equalizerTitle => '均衡器';

  @override
  String get failedStatus => '失败';

  @override
  String get favorite => '收藏';

  @override
  String favoritesLoadFailed(Object error) {
    return '加载收藏失败：$error';
  }

  @override
  String get favoritesTitle => '收藏';

  @override
  String get featureAll => '全功能';

  @override
  String get featureLifetime => '终身有效';

  @override
  String get featureMultiDevice => '多设备';

  @override
  String get featureUpdates => '持续更新';

  @override
  String get frequentlyPlayed => '最常播放';

  @override
  String get fullscreenPlayer => '全屏播放';

  @override
  String genreAlbumCount(int count) {
    return '$count 专辑';
  }

  @override
  String get genreEmpty => '该流派暂无歌曲';

  @override
  String genreSongCount(int count) {
    return '$count 首歌';
  }

  @override
  String genresLoadFailed(Object error) {
    return '加载流派失败：$error';
  }

  @override
  String get goAddServer => '去添加服务器';

  @override
  String get goDiscover => '去发现音乐';

  @override
  String get goToServerPicker => '前往服务器选择';

  @override
  String get gotIt => '我知道了';

  @override
  String get install => '安装';

  @override
  String get installLater => '稍后安装';

  @override
  String get internetRadio => '网络电台';

  @override
  String get iosNotSupported => 'iOS 暂不支持';

  @override
  String get later => '稍后';

  @override
  String get librarySection => '音乐库';

  @override
  String loadedSongsCount(int count) {
    return '已加载 $count 首';
  }

  @override
  String get localOutputOnly => '已使用本地高质量音频输出';

  @override
  String get logout => '退出登录';

  @override
  String get loopAll => '循环模式：列表循环';

  @override
  String get loopAllShort => '列表循环';

  @override
  String get loopOff => '循环模式：关闭';

  @override
  String get loopOffShort => '单曲/列表不循环';

  @override
  String get loopOne => '循环模式：单曲循环';

  @override
  String get loopOneShort => '单曲循环';

  @override
  String get lyrics => '歌词';

  @override
  String get membershipLifetimeNote => '购买后将永久享有会员资格。';

  @override
  String get membershipNote => '1. 会员最多可同时在 7 台装置上登录。';

  @override
  String minutesLabel(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get mute => '静音';

  @override
  String get myMembership => '我的会员';

  @override
  String get myPlaylists => '我的歌单';

  @override
  String get navAlbums => '专辑';

  @override
  String get navArtists => '艺术家';

  @override
  String get navDiscover => '发现';

  @override
  String get navDownloads => '下载管理';

  @override
  String get navDownloadsShort => '下载';

  @override
  String get navFavorites => '我喜欢的';

  @override
  String get navGenres => '流派';

  @override
  String get navLiked => '喜欢';

  @override
  String get navRadios => '电台';

  @override
  String get navSongs => '歌曲';

  @override
  String get nextTrack => '下一首';

  @override
  String get noContentYet => '暂时没有内容';

  @override
  String get noData => '暂无数据';

  @override
  String get noFavoriteAlbums => '还没有收藏专辑。';

  @override
  String get noFavoriteArtists => '还没有收藏歌手。';

  @override
  String get noFavoriteSongs => '还没有收藏歌曲。';

  @override
  String get noLyrics => '这首歌还没有可用歌词';

  @override
  String get noMatchingAsset => '当前平台暂无匹配的安装包，将打开 GitHub Release 页面。';

  @override
  String get noPlaylists => '暂无歌单';

  @override
  String get noSearchMatches => '没有找到匹配内容。';

  @override
  String get noServerMessage => '请先在服务器选择页添加或连接一个音乐库。';

  @override
  String get noSongHistory => '暂无歌曲记录';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get openDownload => '前往下载';

  @override
  String get openDownloadPage => '前往下载页';

  @override
  String get pause => '暂停';

  @override
  String get personalSection => '个人';

  @override
  String get pictureInPicture => '画中画';

  @override
  String get play => '播放';

  @override
  String get playAll => '播放全部';

  @override
  String get playInOrder => '顺序播放';

  @override
  String get playNext => '下一首播放';

  @override
  String playbackFailed(Object error) {
    return '播放失败：$error';
  }

  @override
  String get playlistEmpty => '这个歌单没有歌曲。';

  @override
  String get playlistsLabel => '歌单';

  @override
  String playlistsLoadFailed(Object error) {
    return '加载歌单失败：$error';
  }

  @override
  String get popularSongs => '热门歌曲';

  @override
  String get preparingInstall => '正在准备安装，请稍候…';

  @override
  String get presetClassical => '古典';

  @override
  String get presetFlat => '平直';

  @override
  String get presetLabel => '预设';

  @override
  String get presetPop => '流行';

  @override
  String get presetRock => '摇滚';

  @override
  String get presetVocal => '人声';

  @override
  String get previousTrack => '上一首';

  @override
  String get privacyBody1 => '1. 本应用（音流）为开源独立音乐客户端。';

  @override
  String get privacyBody2 =>
      '2. 本地存储：您的服务器地址、用户名、密码均仅存储在您本机设备的加密/受保护数据库中，绝不上传至任何第三方服务器。';

  @override
  String get privacyBody3 =>
      '3. 网络通讯：本应用仅直接与您所配置的自建音乐服务器（如 Navidrome、Subsonic 等）进行通讯。';

  @override
  String get privacyBody4 => '4. 音频缓存与下载：您选择离线下载的歌曲将仅保留在您的本机磁盘中，随时可手动管理与清除。';

  @override
  String get privacyPolicyTitle => '隐私政策与条款';

  @override
  String queueSongCount(int count) {
    return '$count 首';
  }

  @override
  String get queueTitle => '播放队列';

  @override
  String get randomAlbums => '随机专辑';

  @override
  String get recentlyAdded => '最近新增';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get refresh => '刷新';

  @override
  String get refreshBatch => '换一批';

  @override
  String get refreshSongs => '刷新歌曲';

  @override
  String get releaseNotes => '发布说明';

  @override
  String get restartAndInstall => '重启并安装';

  @override
  String searchFailed(Object error) {
    return '搜索失败：$error';
  }

  @override
  String get searchHint => '搜索歌曲、专辑、艺术家...';

  @override
  String get searchHistory => '搜索历史';

  @override
  String searchHistoryLoadFailed(Object error) {
    return '读取搜索历史失败：$error';
  }

  @override
  String get sectionCompleted => '已完成';

  @override
  String get sectionInProgress => '进行中';

  @override
  String get shuffleOff => '关闭随机播放';

  @override
  String get shuffleOn => '开启随机播放';

  @override
  String get shufflePlay => '随机播放';

  @override
  String get sleepTimer => '睡眠定时';

  @override
  String get sleepTimerAfterCurrent => '播完当前歌曲后停止';

  @override
  String sleepTimerSet(int minutes) {
    return '已设置 $minutes 分钟后停止播放';
  }

  @override
  String sleepTimerSetLabel(Object label) {
    return '已设置睡眠定时：$label';
  }

  @override
  String get sleepTimerTitle => '睡眠定时器';

  @override
  String songCountLabel(int count) {
    return '$count 首歌曲';
  }

  @override
  String songCountText(int count) {
    return '共 $count 首';
  }

  @override
  String songsLoadFailed(Object error) {
    return '加载歌曲失败：$error';
  }

  @override
  String get sortAlbum => '专辑';

  @override
  String get sortArtist => '艺术家';

  @override
  String get sortBy => '排序方式';

  @override
  String get sortDuration => '时长';

  @override
  String get sortFormat => '音质格式';

  @override
  String get sortRecent => '最近添加';

  @override
  String get sortTitle => '歌曲名';

  @override
  String starFailed(Object error) {
    return '收藏失败：$error';
  }

  @override
  String get unfavorite => '取消收藏';

  @override
  String get unknownArtist => '未知艺术家';

  @override
  String get unmute => '取消静音';

  @override
  String unstarFailed(Object error) {
    return '取消收藏失败：$error';
  }

  @override
  String get updateDownloading => '正在下载…';

  @override
  String updateDownloadingPercent(int percent) {
    return '正在下载 $percent%';
  }

  @override
  String get updateNow => '立即更新';

  @override
  String get updatingFavorite => '正在更新收藏';

  @override
  String get viewAlbum => '查看专辑';

  @override
  String get viewAll => '查看全部 ->';

  @override
  String get viewArtist => '查看艺术家';

  @override
  String get debugDiagnostics => '调试诊断';

  @override
  String get debugTitle => '调试与诊断';

  @override
  String get debugSnapshot => '实时快照';

  @override
  String get debugAudioSession => '音频会话';

  @override
  String get debugSafeAudioMode => '安全音频模式';

  @override
  String get debugSafeAudioHint => '关闭 Android 均衡器音频管线；修改后需重启应用才能生效。';

  @override
  String get debugSelfTest => '播放自检';

  @override
  String get debugSelfTestHint => '使用裸 AudioPlayer 直接播放当前曲目，用于对照主播放管线是否无声。';

  @override
  String get debugSelfTestStart => '开始自检';

  @override
  String get debugSelfTestStop => '停止自检';

  @override
  String get debugSelfTestPlaying => '自检播放中…';

  @override
  String get debugSelfTestIdle => '自检未运行';

  @override
  String get debugNoTrack => '当前没有正在播放的曲目，无法启动自检。';

  @override
  String get debugLog => '事件日志';

  @override
  String get debugLogEmpty => '暂无日志，播放一首歌试试。';

  @override
  String get debugCopyLog => '复制日志';

  @override
  String get debugCopied => '日志已复制到剪贴板';

  @override
  String get debugStatus => '状态';

  @override
  String get debugPlaying => '播放中';

  @override
  String get debugPosition => '位置';

  @override
  String get debugDuration => '时长';

  @override
  String get debugVolume => '音量';

  @override
  String get debugIndex => '当前索引';

  @override
  String get debugQueueLen => '队列长度';

  @override
  String get debugActive => '会话激活';

  @override
  String get debugOutputDevices => '输出设备';

  @override
  String get debugOutputDeviceDefault => '跟随系统默认';

  @override
  String debugOutputDeviceApplied(Object name) {
    return '输出设备已切换为「$name」';
  }

  @override
  String get debugOutputDeviceFailed => '切换输出设备失败';

  @override
  String get debugSessionUnknown => '未知';

  @override
  String get addServerTitle => '添加服务器';

  @override
  String get lanDiscovery => '局域网探索';

  @override
  String get lanRefresh => '刷新局域网搜索';

  @override
  String get searchingLan => '正在搜索局域网中的音乐服务器…';

  @override
  String get noServersFound => '未发现任何服务器';

  @override
  String get ensureSameNetwork => '请确认设备处于同一局域网';

  @override
  String get manualAdd => '手动添加';

  @override
  String get comingSoon => '即将支持';
}
