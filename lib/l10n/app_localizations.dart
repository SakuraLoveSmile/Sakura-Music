import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'SakuraMusic'**
  String get appName;

  /// No description provided for @viewSwitch.
  ///
  /// In zh, this message translates to:
  /// **'视图切换'**
  String get viewSwitch;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @welcomeTagline.
  ///
  /// In zh, this message translates to:
  /// **'连接你的音乐'**
  String get welcomeTagline;

  /// No description provided for @privacyPrefix.
  ///
  /// In zh, this message translates to:
  /// **'继续使用即表示同意 '**
  String get privacyPrefix;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @addedTapCardHint.
  ///
  /// In zh, this message translates to:
  /// **'已添加，点击卡片进入'**
  String get addedTapCardHint;

  /// No description provided for @featureMultiSource.
  ///
  /// In zh, this message translates to:
  /// **'多源支持'**
  String get featureMultiSource;

  /// No description provided for @featureMultiSourceDesc.
  ///
  /// In zh, this message translates to:
  /// **'支持 Navidrome、Emby 等多种服务器协议'**
  String get featureMultiSourceDesc;

  /// No description provided for @featureLossless.
  ///
  /// In zh, this message translates to:
  /// **'无损播放'**
  String get featureLossless;

  /// No description provided for @featureLosslessDesc.
  ///
  /// In zh, this message translates to:
  /// **'Hi-Res 音质'**
  String get featureLosslessDesc;

  /// No description provided for @featureNative.
  ///
  /// In zh, this message translates to:
  /// **'原生体验'**
  String get featureNative;

  /// No description provided for @featureNativeDesc.
  ///
  /// In zh, this message translates to:
  /// **'SwiftUI 构建'**
  String get featureNativeDesc;

  /// No description provided for @featureCrossPlatform.
  ///
  /// In zh, this message translates to:
  /// **'全平台支持'**
  String get featureCrossPlatform;

  /// No description provided for @featureCrossPlatformDesc.
  ///
  /// In zh, this message translates to:
  /// **'iOS、macOS、tvOS 无缝切换'**
  String get featureCrossPlatformDesc;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @welcomeNav.
  ///
  /// In zh, this message translates to:
  /// **'欢迎'**
  String get welcomeNav;

  /// No description provided for @serversSection.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get serversSection;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{message}'**
  String loadFailed(Object message);

  /// No description provided for @noServers.
  ///
  /// In zh, this message translates to:
  /// **'暂无服务器'**
  String get noServers;

  /// No description provided for @noSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'无符合结果'**
  String get noSearchResults;

  /// No description provided for @addServer.
  ///
  /// In zh, this message translates to:
  /// **'新增服务器'**
  String get addServer;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @chooseLibrary.
  ///
  /// In zh, this message translates to:
  /// **'选择媒体库'**
  String get chooseLibrary;

  /// No description provided for @serverCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 台服务器'**
  String serverCount(int count);

  /// No description provided for @currentBadge.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get currentBadge;

  /// No description provided for @emptyPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有服务器'**
  String get emptyPickerTitle;

  /// No description provided for @emptyPickerDesc.
  ///
  /// In zh, this message translates to:
  /// **'添加你的第一台服务器，连接你的音乐'**
  String get emptyPickerDesc;

  /// No description provided for @addFirstServer.
  ///
  /// In zh, this message translates to:
  /// **'添加第一台服务器'**
  String get addFirstServer;

  /// No description provided for @editServer.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get editServer;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @serverType.
  ///
  /// In zh, this message translates to:
  /// **'服务器类型'**
  String get serverType;

  /// No description provided for @serverName.
  ///
  /// In zh, this message translates to:
  /// **'服务器名称'**
  String get serverName;

  /// No description provided for @serverNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如：我的 Navidrome'**
  String get serverNameHint;

  /// No description provided for @pleaseInputServerName.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器名称'**
  String get pleaseInputServerName;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @hostLabel.
  ///
  /// In zh, this message translates to:
  /// **'主机'**
  String get hostLabel;

  /// No description provided for @pleaseInputServerAddress.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器地址'**
  String get pleaseInputServerAddress;

  /// No description provided for @hostNoScheme.
  ///
  /// In zh, this message translates to:
  /// **'无需填写协议，请只输入主机'**
  String get hostNoScheme;

  /// No description provided for @portInRightField.
  ///
  /// In zh, this message translates to:
  /// **'端口请填写在端口输入框'**
  String get portInRightField;

  /// No description provided for @portLabel.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get portLabel;

  /// No description provided for @portRange.
  ///
  /// In zh, this message translates to:
  /// **'1–65535'**
  String get portRange;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'账号 / 用户名'**
  String get username;

  /// No description provided for @pleaseInputUsername.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get pleaseInputUsername;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @pleaseInputPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get pleaseInputPassword;

  /// No description provided for @connectSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接成功！服务器通信正常。'**
  String get connectSuccess;

  /// No description provided for @connectFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{message}'**
  String connectFailed(Object message);

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String saveFailed(Object error);

  /// No description provided for @loadError.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadError;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @saveChanges.
  ///
  /// In zh, this message translates to:
  /// **'保存修改'**
  String get saveChanges;

  /// No description provided for @saveAndConnect.
  ///
  /// In zh, this message translates to:
  /// **'保存并连接'**
  String get saveAndConnect;

  /// No description provided for @deleteServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除服务器？'**
  String get deleteServerTitle;

  /// No description provided for @deleteServerConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除「{name}」吗？这只会移除本地保存的连接信息。'**
  String deleteServerConfirm(Object name);

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @exitConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出应用？'**
  String get exitConfirmTitle;

  /// No description provided for @exitConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出 SakuraMusic 吗？'**
  String get exitConfirmMessage;

  /// No description provided for @exitApp.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exitApp;

  /// No description provided for @switchLibrary.
  ///
  /// In zh, this message translates to:
  /// **'切换音乐库'**
  String get switchLibrary;

  /// No description provided for @membership.
  ///
  /// In zh, this message translates to:
  /// **'会员'**
  String get membership;

  /// No description provided for @membershipActivated.
  ///
  /// In zh, this message translates to:
  /// **'已激活'**
  String get membershipActivated;

  /// No description provided for @activateMembership.
  ///
  /// In zh, this message translates to:
  /// **'开通会员'**
  String get activateMembership;

  /// No description provided for @activateMembershipSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'通过激活码或 Star 开源仓库即可激活全部会员权益'**
  String get activateMembershipSubtitle;

  /// No description provided for @membershipActiveBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'会员已激活'**
  String get membershipActiveBannerTitle;

  /// No description provided for @activationCodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'激活码激活'**
  String get activationCodeTitle;

  /// No description provided for @activationCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入激活码'**
  String get activationCodeHint;

  /// No description provided for @activateButton.
  ///
  /// In zh, this message translates to:
  /// **'激活'**
  String get activateButton;

  /// No description provided for @activationSuccess.
  ///
  /// In zh, this message translates to:
  /// **'激活成功，已开通会员功能！'**
  String get activationSuccess;

  /// No description provided for @activationCodeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'激活码无效，请检查后重试'**
  String get activationCodeInvalid;

  /// No description provided for @starActivationTitle.
  ///
  /// In zh, this message translates to:
  /// **'Star 点亮激活'**
  String get starActivationTitle;

  /// No description provided for @starActivationDesc.
  ///
  /// In zh, this message translates to:
  /// **'如果你已在 GitHub 上为本项目点亮 Star，可开启此开关直接激活。我们不做联网检测，请凭诚信开启。'**
  String get starActivationDesc;

  /// No description provided for @goToStar.
  ///
  /// In zh, this message translates to:
  /// **'前往 Star'**
  String get goToStar;

  /// No description provided for @activatedViaCode.
  ///
  /// In zh, this message translates to:
  /// **'激活方式：激活码'**
  String get activatedViaCode;

  /// No description provided for @activatedViaStar.
  ///
  /// In zh, this message translates to:
  /// **'激活方式：Star 诚信激活'**
  String get activatedViaStar;

  /// No description provided for @deactivateMembership.
  ///
  /// In zh, this message translates to:
  /// **'取消激活'**
  String get deactivateMembership;

  /// No description provided for @deactivatedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已取消会员激活'**
  String get deactivatedSuccess;

  /// No description provided for @notActivated.
  ///
  /// In zh, this message translates to:
  /// **'未开通'**
  String get notActivated;

  /// No description provided for @sectionPlayback.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get sectionPlayback;

  /// No description provided for @autoPlayOnLaunch.
  ///
  /// In zh, this message translates to:
  /// **'启动后自动播放'**
  String get autoPlayOnLaunch;

  /// No description provided for @fadeTransition.
  ///
  /// In zh, this message translates to:
  /// **'淡入淡出'**
  String get fadeTransition;

  /// No description provided for @musicRoaming.
  ///
  /// In zh, this message translates to:
  /// **'音乐漫游'**
  String get musicRoaming;

  /// No description provided for @streamingQuality.
  ///
  /// In zh, this message translates to:
  /// **'在线播放音质'**
  String get streamingQuality;

  /// No description provided for @equalizerSettings.
  ///
  /// In zh, this message translates to:
  /// **'均衡器设置'**
  String get equalizerSettings;

  /// No description provided for @lyricsOverlay.
  ///
  /// In zh, this message translates to:
  /// **'桌面悬浮歌词'**
  String get lyricsOverlay;

  /// No description provided for @lyricsOverlayPermissionNeeded.
  ///
  /// In zh, this message translates to:
  /// **'需要悬浮窗权限，请在系统设置中授予后重试'**
  String get lyricsOverlayPermissionNeeded;

  /// No description provided for @statusBarLyrics.
  ///
  /// In zh, this message translates to:
  /// **'状态栏歌词 (Lyricon)'**
  String get statusBarLyrics;

  /// No description provided for @statusBarLyricsDesc.
  ///
  /// In zh, this message translates to:
  /// **'将当前播放的歌曲与歌词同步到状态栏（需设备已安装 LSPosed 与 Lyricon），未安装时自动忽略。'**
  String get statusBarLyricsDesc;

  /// No description provided for @sectionNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络'**
  String get sectionNetwork;

  /// No description provided for @backgroundDownload.
  ///
  /// In zh, this message translates to:
  /// **'后台下载'**
  String get backgroundDownload;

  /// No description provided for @downloadWifiOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅 Wi-Fi'**
  String get downloadWifiOnly;

  /// No description provided for @downloadAnyNetwork.
  ///
  /// In zh, this message translates to:
  /// **'所有网络'**
  String get downloadAnyNetwork;

  /// No description provided for @downloadOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get downloadOff;

  /// No description provided for @networkProxy.
  ///
  /// In zh, this message translates to:
  /// **'网络代理'**
  String get networkProxy;

  /// No description provided for @sectionStorage.
  ///
  /// In zh, this message translates to:
  /// **'存储与服务'**
  String get sectionStorage;

  /// No description provided for @serverManagement.
  ///
  /// In zh, this message translates to:
  /// **'服务器管理'**
  String get serverManagement;

  /// No description provided for @notConnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get notConnected;

  /// No description provided for @addNewServer.
  ///
  /// In zh, this message translates to:
  /// **'添加新服务器'**
  String get addNewServer;

  /// No description provided for @clearCache.
  ///
  /// In zh, this message translates to:
  /// **'清除歌曲缓存'**
  String get clearCache;

  /// No description provided for @cacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除本地临时缓存数据'**
  String get cacheCleared;

  /// No description provided for @sectionAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get sectionAppearance;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @sectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get sectionAbout;

  /// No description provided for @currentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get currentVersion;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'读取中…'**
  String get loading;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @checkUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdates;

  /// No description provided for @updateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateAvailable;

  /// No description provided for @downloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloading;

  /// No description provided for @downloaded.
  ///
  /// In zh, this message translates to:
  /// **'已下载'**
  String get downloaded;

  /// No description provided for @installing.
  ///
  /// In zh, this message translates to:
  /// **'安装中'**
  String get installing;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @upToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get upToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get updateCheckFailed;

  /// No description provided for @qualityLosslessAuto.
  ///
  /// In zh, this message translates to:
  /// **'无损 / 自动'**
  String get qualityLosslessAuto;

  /// No description provided for @qualityFlacWav.
  ///
  /// In zh, this message translates to:
  /// **'FLAC / WAV 极高音质'**
  String get qualityFlacWav;

  /// No description provided for @quality320.
  ///
  /// In zh, this message translates to:
  /// **'320 kbps MP3 高音质'**
  String get quality320;

  /// No description provided for @quality192.
  ///
  /// In zh, this message translates to:
  /// **'192 kbps MP3 标准音质'**
  String get quality192;

  /// No description provided for @quality128.
  ///
  /// In zh, this message translates to:
  /// **'128 kbps MP3 流畅节省流量'**
  String get quality128;

  /// No description provided for @proxyDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络代理设置'**
  String get proxyDialogTitle;

  /// No description provided for @proxyAddressLabel.
  ///
  /// In zh, this message translates to:
  /// **'HTTP / SOCKS5 代理地址'**
  String get proxyAddressLabel;

  /// No description provided for @proxySaved.
  ///
  /// In zh, this message translates to:
  /// **'网络代理设置已保存'**
  String get proxySaved;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @aboutSection.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get aboutSection;

  /// No description provided for @addLibraryFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先在服务器页添加一个音乐库。'**
  String get addLibraryFirst;

  /// No description provided for @addToQueue.
  ///
  /// In zh, this message translates to:
  /// **'追加到队列'**
  String get addToQueue;

  /// No description provided for @addedToDownloads.
  ///
  /// In zh, this message translates to:
  /// **'已添加「{title}」至下载队列'**
  String addedToDownloads(Object title);

  /// No description provided for @addedToPlayNext.
  ///
  /// In zh, this message translates to:
  /// **'已将「{title}」添加到下一首播放'**
  String addedToPlayNext(Object title);

  /// No description provided for @addedToQueue.
  ///
  /// In zh, this message translates to:
  /// **'已追加到队列'**
  String get addedToQueue;

  /// No description provided for @albumEmptyTracks.
  ///
  /// In zh, this message translates to:
  /// **'这个专辑没有可播放的曲目。'**
  String get albumEmptyTracks;

  /// No description provided for @albumLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载专辑详情失败：{error}'**
  String albumLoadFailed(Object error);

  /// No description provided for @albumsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载专辑失败：{error}'**
  String albumsLoadFailed(Object error);

  /// No description provided for @allAlbumsLoaded.
  ///
  /// In zh, this message translates to:
  /// **'已加载全部专辑'**
  String get allAlbumsLoaded;

  /// No description provided for @artistAlbumCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 张专辑'**
  String artistAlbumCount(int count);

  /// No description provided for @artistsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载歌手失败：{error}'**
  String artistsLoadFailed(Object error);

  /// No description provided for @assetInfo.
  ///
  /// In zh, this message translates to:
  /// **'安装包：{name} · {size}'**
  String assetInfo(Object name, Object size);

  /// No description provided for @browse.
  ///
  /// In zh, this message translates to:
  /// **'浏览'**
  String get browse;

  /// No description provided for @cancelDownload.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get cancelDownload;

  /// No description provided for @cast.
  ///
  /// In zh, this message translates to:
  /// **'投播'**
  String get cast;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @clearHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空历史'**
  String get clearHistory;

  /// No description provided for @collapsePlayer.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapsePlayer;

  /// No description provided for @connectedLibraries.
  ///
  /// In zh, this message translates to:
  /// **'已连接的音乐库'**
  String get connectedLibraries;

  /// No description provided for @dailyMixSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'根据你的收听偏好智能推荐'**
  String get dailyMixSubtitle;

  /// No description provided for @dailyMixTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日私享歌单'**
  String get dailyMixTitle;

  /// No description provided for @dailyRecommend.
  ///
  /// In zh, this message translates to:
  /// **'每日推荐'**
  String get dailyRecommend;

  /// No description provided for @deleteDownload.
  ///
  /// In zh, this message translates to:
  /// **'删除下载'**
  String get deleteDownload;

  /// No description provided for @download.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// No description provided for @downloadSong.
  ///
  /// In zh, this message translates to:
  /// **'下载歌曲'**
  String get downloadSong;

  /// No description provided for @downloadsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取下载失败：{error}'**
  String downloadsLoadFailed(Object error);

  /// No description provided for @emptyAlbums.
  ///
  /// In zh, this message translates to:
  /// **'服务器中还没有专辑。'**
  String get emptyAlbums;

  /// No description provided for @emptyArtists.
  ///
  /// In zh, this message translates to:
  /// **'服务器中还没有歌手。'**
  String get emptyArtists;

  /// No description provided for @emptyDownloads.
  ///
  /// In zh, this message translates to:
  /// **'还没有下载歌曲。'**
  String get emptyDownloads;

  /// No description provided for @emptyGenres.
  ///
  /// In zh, this message translates to:
  /// **'音乐库中还没有流派信息'**
  String get emptyGenres;

  /// No description provided for @emptyLibrarySongs.
  ///
  /// In zh, this message translates to:
  /// **'音乐库中还没有歌曲'**
  String get emptyLibrarySongs;

  /// No description provided for @emptyPlayerDesc.
  ///
  /// In zh, this message translates to:
  /// **'从歌曲或专辑列表中选择一首歌曲开始播放。'**
  String get emptyPlayerDesc;

  /// No description provided for @emptyPlayerTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有正在播放的歌曲'**
  String get emptyPlayerTitle;

  /// No description provided for @emptyPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'还没有歌单。'**
  String get emptyPlaylists;

  /// No description provided for @emptyQueue.
  ///
  /// In zh, this message translates to:
  /// **'播放队列为空。'**
  String get emptyQueue;

  /// No description provided for @emptySearchHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无搜索历史，输入关键词回车搜索。'**
  String get emptySearchHistory;

  /// No description provided for @enableEqualizer.
  ///
  /// In zh, this message translates to:
  /// **'启用均衡器'**
  String get enableEqualizer;

  /// No description provided for @equalizerLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取均衡器设置失败：{error}'**
  String equalizerLoadFailed(Object error);

  /// No description provided for @equalizerTitle.
  ///
  /// In zh, this message translates to:
  /// **'均衡器'**
  String get equalizerTitle;

  /// No description provided for @failedStatus.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failedStatus;

  /// No description provided for @favorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorite;

  /// No description provided for @favoritesLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载收藏失败：{error}'**
  String favoritesLoadFailed(Object error);

  /// No description provided for @favoritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favoritesTitle;

  /// No description provided for @featureAll.
  ///
  /// In zh, this message translates to:
  /// **'全功能'**
  String get featureAll;

  /// No description provided for @featureLifetime.
  ///
  /// In zh, this message translates to:
  /// **'终身有效'**
  String get featureLifetime;

  /// No description provided for @featureMultiDevice.
  ///
  /// In zh, this message translates to:
  /// **'多设备'**
  String get featureMultiDevice;

  /// No description provided for @featureUpdates.
  ///
  /// In zh, this message translates to:
  /// **'持续更新'**
  String get featureUpdates;

  /// No description provided for @frequentlyPlayed.
  ///
  /// In zh, this message translates to:
  /// **'最常播放'**
  String get frequentlyPlayed;

  /// No description provided for @fullscreenPlayer.
  ///
  /// In zh, this message translates to:
  /// **'全屏播放'**
  String get fullscreenPlayer;

  /// No description provided for @genreAlbumCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 专辑'**
  String genreAlbumCount(int count);

  /// No description provided for @genreEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该流派暂无歌曲'**
  String get genreEmpty;

  /// No description provided for @genreSongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首歌'**
  String genreSongCount(int count);

  /// No description provided for @genresLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载流派失败：{error}'**
  String genresLoadFailed(Object error);

  /// No description provided for @goAddServer.
  ///
  /// In zh, this message translates to:
  /// **'去添加服务器'**
  String get goAddServer;

  /// No description provided for @goDiscover.
  ///
  /// In zh, this message translates to:
  /// **'去发现音乐'**
  String get goDiscover;

  /// No description provided for @goToServerPicker.
  ///
  /// In zh, this message translates to:
  /// **'前往服务器选择'**
  String get goToServerPicker;

  /// No description provided for @gotIt.
  ///
  /// In zh, this message translates to:
  /// **'我知道了'**
  String get gotIt;

  /// No description provided for @install.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get install;

  /// No description provided for @installLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后安装'**
  String get installLater;

  /// No description provided for @internetRadio.
  ///
  /// In zh, this message translates to:
  /// **'网络电台'**
  String get internetRadio;

  /// No description provided for @iosNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'iOS 暂不支持'**
  String get iosNotSupported;

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get later;

  /// No description provided for @librarySection.
  ///
  /// In zh, this message translates to:
  /// **'音乐库'**
  String get librarySection;

  /// No description provided for @loadedSongsCount.
  ///
  /// In zh, this message translates to:
  /// **'已加载 {count} 首'**
  String loadedSongsCount(int count);

  /// No description provided for @localOutputOnly.
  ///
  /// In zh, this message translates to:
  /// **'已使用本地高质量音频输出'**
  String get localOutputOnly;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @loopAll.
  ///
  /// In zh, this message translates to:
  /// **'循环模式：列表循环'**
  String get loopAll;

  /// No description provided for @loopAllShort.
  ///
  /// In zh, this message translates to:
  /// **'列表循环'**
  String get loopAllShort;

  /// No description provided for @loopOff.
  ///
  /// In zh, this message translates to:
  /// **'循环模式：关闭'**
  String get loopOff;

  /// No description provided for @loopOffShort.
  ///
  /// In zh, this message translates to:
  /// **'单曲/列表不循环'**
  String get loopOffShort;

  /// No description provided for @loopOne.
  ///
  /// In zh, this message translates to:
  /// **'循环模式：单曲循环'**
  String get loopOne;

  /// No description provided for @loopOneShort.
  ///
  /// In zh, this message translates to:
  /// **'单曲循环'**
  String get loopOneShort;

  /// No description provided for @lyrics.
  ///
  /// In zh, this message translates to:
  /// **'歌词'**
  String get lyrics;

  /// No description provided for @membershipLifetimeNote.
  ///
  /// In zh, this message translates to:
  /// **'购买后将永久享有会员资格。'**
  String get membershipLifetimeNote;

  /// No description provided for @membershipNote.
  ///
  /// In zh, this message translates to:
  /// **'1. 会员最多可同时在 7 台装置上登录。'**
  String get membershipNote;

  /// No description provided for @minutesLabel.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String minutesLabel(int minutes);

  /// No description provided for @mute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get mute;

  /// No description provided for @myMembership.
  ///
  /// In zh, this message translates to:
  /// **'我的会员'**
  String get myMembership;

  /// No description provided for @myPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'我的歌单'**
  String get myPlaylists;

  /// No description provided for @navAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get navAlbums;

  /// No description provided for @navArtists.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get navArtists;

  /// No description provided for @navDiscover.
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get navDiscover;

  /// No description provided for @navDownloads.
  ///
  /// In zh, this message translates to:
  /// **'下载管理'**
  String get navDownloads;

  /// No description provided for @navDownloadsShort.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get navDownloadsShort;

  /// No description provided for @navFavorites.
  ///
  /// In zh, this message translates to:
  /// **'我喜欢的'**
  String get navFavorites;

  /// No description provided for @navGenres.
  ///
  /// In zh, this message translates to:
  /// **'流派'**
  String get navGenres;

  /// No description provided for @navLiked.
  ///
  /// In zh, this message translates to:
  /// **'喜欢'**
  String get navLiked;

  /// No description provided for @navRadios.
  ///
  /// In zh, this message translates to:
  /// **'电台'**
  String get navRadios;

  /// No description provided for @navSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get navSongs;

  /// No description provided for @nextTrack.
  ///
  /// In zh, this message translates to:
  /// **'下一首'**
  String get nextTrack;

  /// No description provided for @noContentYet.
  ///
  /// In zh, this message translates to:
  /// **'暂时没有内容'**
  String get noContentYet;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @noFavoriteAlbums.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏专辑。'**
  String get noFavoriteAlbums;

  /// No description provided for @noFavoriteArtists.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏歌手。'**
  String get noFavoriteArtists;

  /// No description provided for @noFavoriteSongs.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏歌曲。'**
  String get noFavoriteSongs;

  /// No description provided for @noLyrics.
  ///
  /// In zh, this message translates to:
  /// **'这首歌还没有可用歌词'**
  String get noLyrics;

  /// No description provided for @noMatchingAsset.
  ///
  /// In zh, this message translates to:
  /// **'当前平台暂无匹配的安装包，将打开 GitHub Release 页面。'**
  String get noMatchingAsset;

  /// No description provided for @noPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌单'**
  String get noPlaylists;

  /// No description provided for @noSearchMatches.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配内容。'**
  String get noSearchMatches;

  /// No description provided for @noServerMessage.
  ///
  /// In zh, this message translates to:
  /// **'请先在服务器选择页添加或连接一个音乐库。'**
  String get noServerMessage;

  /// No description provided for @noSongHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌曲记录'**
  String get noSongHistory;

  /// No description provided for @nowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get nowPlaying;

  /// No description provided for @openDownload.
  ///
  /// In zh, this message translates to:
  /// **'前往下载'**
  String get openDownload;

  /// No description provided for @openDownloadPage.
  ///
  /// In zh, this message translates to:
  /// **'前往下载页'**
  String get openDownloadPage;

  /// No description provided for @pause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// No description provided for @personalSection.
  ///
  /// In zh, this message translates to:
  /// **'个人'**
  String get personalSection;

  /// No description provided for @pictureInPicture.
  ///
  /// In zh, this message translates to:
  /// **'画中画'**
  String get pictureInPicture;

  /// No description provided for @play.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get play;

  /// No description provided for @playAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get playAll;

  /// No description provided for @playInOrder.
  ///
  /// In zh, this message translates to:
  /// **'顺序播放'**
  String get playInOrder;

  /// No description provided for @playNext.
  ///
  /// In zh, this message translates to:
  /// **'下一首播放'**
  String get playNext;

  /// No description provided for @playbackFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放失败：{error}'**
  String playbackFailed(Object error);

  /// No description provided for @playlistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'这个歌单没有歌曲。'**
  String get playlistEmpty;

  /// No description provided for @playlistsLabel.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get playlistsLabel;

  /// No description provided for @playlistsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载歌单失败：{error}'**
  String playlistsLoadFailed(Object error);

  /// No description provided for @popularSongs.
  ///
  /// In zh, this message translates to:
  /// **'热门歌曲'**
  String get popularSongs;

  /// No description provided for @preparingInstall.
  ///
  /// In zh, this message translates to:
  /// **'正在准备安装，请稍候…'**
  String get preparingInstall;

  /// No description provided for @oledSettings.
  ///
  /// In zh, this message translates to:
  /// **'全黑歌词设置'**
  String get oledSettings;

  /// No description provided for @keepScreenAwake.
  ///
  /// In zh, this message translates to:
  /// **'屏幕常亮（不休眠）'**
  String get keepScreenAwake;

  /// No description provided for @lyricsFontSize.
  ///
  /// In zh, this message translates to:
  /// **'歌词字号'**
  String get lyricsFontSize;

  /// No description provided for @lyricsAlignment.
  ///
  /// In zh, this message translates to:
  /// **'对齐方式'**
  String get lyricsAlignment;

  /// No description provided for @alignCenter.
  ///
  /// In zh, this message translates to:
  /// **'居中对齐'**
  String get alignCenter;

  /// No description provided for @alignLeft.
  ///
  /// In zh, this message translates to:
  /// **'居左对齐'**
  String get alignLeft;

  /// No description provided for @showTranslation.
  ///
  /// In zh, this message translates to:
  /// **'显示翻译'**
  String get showTranslation;

  /// No description provided for @showClock.
  ///
  /// In zh, this message translates to:
  /// **'显示时钟'**
  String get showClock;

  /// No description provided for @presetClassical.
  ///
  /// In zh, this message translates to:
  /// **'古典'**
  String get presetClassical;

  /// No description provided for @presetFlat.
  ///
  /// In zh, this message translates to:
  /// **'平直'**
  String get presetFlat;

  /// No description provided for @presetLabel.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get presetLabel;

  /// No description provided for @presetPop.
  ///
  /// In zh, this message translates to:
  /// **'流行'**
  String get presetPop;

  /// No description provided for @presetRock.
  ///
  /// In zh, this message translates to:
  /// **'摇滚'**
  String get presetRock;

  /// No description provided for @presetVocal.
  ///
  /// In zh, this message translates to:
  /// **'人声'**
  String get presetVocal;

  /// No description provided for @previousTrack.
  ///
  /// In zh, this message translates to:
  /// **'上一首'**
  String get previousTrack;

  /// No description provided for @privacyBody1.
  ///
  /// In zh, this message translates to:
  /// **'1. 本应用（SakuraMusic）为开源独立音乐客户端。'**
  String get privacyBody1;

  /// No description provided for @privacyBody2.
  ///
  /// In zh, this message translates to:
  /// **'2. 本地存储：您的服务器地址、用户名、密码均仅存储在您本机设备的加密/受保护数据库中，绝不上传至任何第三方服务器。'**
  String get privacyBody2;

  /// No description provided for @privacyBody3.
  ///
  /// In zh, this message translates to:
  /// **'3. 网络通讯：本应用仅直接与您所配置的自建音乐服务器（如 Navidrome、Subsonic 等）进行通讯。'**
  String get privacyBody3;

  /// No description provided for @privacyBody4.
  ///
  /// In zh, this message translates to:
  /// **'4. 音频缓存与下载：您选择离线下载的歌曲将仅保留在您的本机磁盘中，随时可手动管理与清除。'**
  String get privacyBody4;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策与条款'**
  String get privacyPolicyTitle;

  /// No description provided for @queueSongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String queueSongCount(int count);

  /// No description provided for @queueTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get queueTitle;

  /// No description provided for @randomAlbums.
  ///
  /// In zh, this message translates to:
  /// **'随机专辑'**
  String get randomAlbums;

  /// No description provided for @randomSongs.
  ///
  /// In zh, this message translates to:
  /// **'随机歌曲'**
  String get randomSongs;

  /// No description provided for @recentlyAdded.
  ///
  /// In zh, this message translates to:
  /// **'最近新增'**
  String get recentlyAdded;

  /// No description provided for @recentlyAddedSongs.
  ///
  /// In zh, this message translates to:
  /// **'最近添加的歌曲'**
  String get recentlyAddedSongs;

  /// No description provided for @recentlyPlayed.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get recentlyPlayed;

  /// No description provided for @recentlyPlayedSongs.
  ///
  /// In zh, this message translates to:
  /// **'最近播放的歌曲'**
  String get recentlyPlayedSongs;

  /// No description provided for @recentlyUpdatedPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'最近更新的歌单'**
  String get recentlyUpdatedPlaylists;

  /// No description provided for @foldersCount.
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get foldersCount;

  /// No description provided for @totalSize.
  ///
  /// In zh, this message translates to:
  /// **'总大小'**
  String get totalSize;

  /// No description provided for @totalDuration.
  ///
  /// In zh, this message translates to:
  /// **'总时长'**
  String get totalDuration;

  /// No description provided for @resolution.
  ///
  /// In zh, this message translates to:
  /// **'分辨率'**
  String get resolution;

  /// No description provided for @customize.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get customize;

  /// No description provided for @myFavorites.
  ///
  /// In zh, this message translates to:
  /// **'喜爱'**
  String get myFavorites;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @refreshBatch.
  ///
  /// In zh, this message translates to:
  /// **'换一批'**
  String get refreshBatch;

  /// No description provided for @refreshSongs.
  ///
  /// In zh, this message translates to:
  /// **'刷新歌曲'**
  String get refreshSongs;

  /// No description provided for @releaseNotes.
  ///
  /// In zh, this message translates to:
  /// **'发布说明'**
  String get releaseNotes;

  /// No description provided for @restartAndInstall.
  ///
  /// In zh, this message translates to:
  /// **'重启并安装'**
  String get restartAndInstall;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败：{error}'**
  String searchFailed(Object error);

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌曲、专辑、艺术家...'**
  String get searchHint;

  /// No description provided for @searchHistory.
  ///
  /// In zh, this message translates to:
  /// **'搜索历史'**
  String get searchHistory;

  /// No description provided for @searchHistoryLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取搜索历史失败：{error}'**
  String searchHistoryLoadFailed(Object error);

  /// No description provided for @sectionCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get sectionCompleted;

  /// No description provided for @sectionInProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get sectionInProgress;

  /// No description provided for @shuffleOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭随机播放'**
  String get shuffleOff;

  /// No description provided for @shuffleOn.
  ///
  /// In zh, this message translates to:
  /// **'开启随机播放'**
  String get shuffleOn;

  /// No description provided for @shufflePlay.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get shufflePlay;

  /// No description provided for @sleepTimer.
  ///
  /// In zh, this message translates to:
  /// **'睡眠定时'**
  String get sleepTimer;

  /// No description provided for @sleepTimerAfterCurrent.
  ///
  /// In zh, this message translates to:
  /// **'播完当前歌曲后停止'**
  String get sleepTimerAfterCurrent;

  /// No description provided for @sleepTimerSet.
  ///
  /// In zh, this message translates to:
  /// **'已设置 {minutes} 分钟后停止播放'**
  String sleepTimerSet(int minutes);

  /// No description provided for @sleepTimerSetLabel.
  ///
  /// In zh, this message translates to:
  /// **'已设置睡眠定时：{label}'**
  String sleepTimerSetLabel(Object label);

  /// No description provided for @sleepTimerTitle.
  ///
  /// In zh, this message translates to:
  /// **'睡眠定时器'**
  String get sleepTimerTitle;

  /// No description provided for @songCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首歌曲'**
  String songCountLabel(int count);

  /// No description provided for @songCountText.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 首'**
  String songCountText(int count);

  /// No description provided for @songsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载歌曲失败：{error}'**
  String songsLoadFailed(Object error);

  /// No description provided for @sortAlbum.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get sortAlbum;

  /// No description provided for @sortArtist.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get sortArtist;

  /// No description provided for @sortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get sortBy;

  /// No description provided for @sortDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get sortDuration;

  /// No description provided for @sortFormat.
  ///
  /// In zh, this message translates to:
  /// **'音质格式'**
  String get sortFormat;

  /// No description provided for @sortRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近添加'**
  String get sortRecent;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌曲名'**
  String get sortTitle;

  /// No description provided for @starFailed.
  ///
  /// In zh, this message translates to:
  /// **'收藏失败：{error}'**
  String starFailed(Object error);

  /// No description provided for @unfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get unfavorite;

  /// No description provided for @unknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知艺术家'**
  String get unknownArtist;

  /// No description provided for @unmute.
  ///
  /// In zh, this message translates to:
  /// **'取消静音'**
  String get unmute;

  /// No description provided for @unstarFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏失败：{error}'**
  String unstarFailed(Object error);

  /// No description provided for @updateDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载…'**
  String get updateDownloading;

  /// No description provided for @updateDownloadingPercent.
  ///
  /// In zh, this message translates to:
  /// **'正在下载 {percent}%'**
  String updateDownloadingPercent(int percent);

  /// No description provided for @updateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get updateNow;

  /// No description provided for @updatingFavorite.
  ///
  /// In zh, this message translates to:
  /// **'正在更新收藏'**
  String get updatingFavorite;

  /// No description provided for @viewAlbum.
  ///
  /// In zh, this message translates to:
  /// **'查看专辑'**
  String get viewAlbum;

  /// No description provided for @viewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部 ->'**
  String get viewAll;

  /// No description provided for @viewArtist.
  ///
  /// In zh, this message translates to:
  /// **'查看艺术家'**
  String get viewArtist;

  /// No description provided for @debugDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'调试诊断'**
  String get debugDiagnostics;

  /// No description provided for @debugTitle.
  ///
  /// In zh, this message translates to:
  /// **'调试与诊断'**
  String get debugTitle;

  /// No description provided for @debugSnapshot.
  ///
  /// In zh, this message translates to:
  /// **'实时快照'**
  String get debugSnapshot;

  /// No description provided for @debugAudioSession.
  ///
  /// In zh, this message translates to:
  /// **'音频会话'**
  String get debugAudioSession;

  /// No description provided for @debugSafeAudioMode.
  ///
  /// In zh, this message translates to:
  /// **'安全音频模式'**
  String get debugSafeAudioMode;

  /// No description provided for @debugSafeAudioHint.
  ///
  /// In zh, this message translates to:
  /// **'关闭 Android 均衡器音频管线；修改后需重启应用才能生效。'**
  String get debugSafeAudioHint;

  /// No description provided for @debugSelfTest.
  ///
  /// In zh, this message translates to:
  /// **'播放自检'**
  String get debugSelfTest;

  /// No description provided for @debugSelfTestHint.
  ///
  /// In zh, this message translates to:
  /// **'使用裸 AudioPlayer 直接播放当前曲目，用于对照主播放管线是否无声。'**
  String get debugSelfTestHint;

  /// No description provided for @debugSelfTestStart.
  ///
  /// In zh, this message translates to:
  /// **'开始自检'**
  String get debugSelfTestStart;

  /// No description provided for @debugSelfTestStop.
  ///
  /// In zh, this message translates to:
  /// **'停止自检'**
  String get debugSelfTestStop;

  /// No description provided for @debugSelfTestPlaying.
  ///
  /// In zh, this message translates to:
  /// **'自检播放中…'**
  String get debugSelfTestPlaying;

  /// No description provided for @debugSelfTestIdle.
  ///
  /// In zh, this message translates to:
  /// **'自检未运行'**
  String get debugSelfTestIdle;

  /// No description provided for @debugNoTrack.
  ///
  /// In zh, this message translates to:
  /// **'当前没有正在播放的曲目，无法启动自检。'**
  String get debugNoTrack;

  /// No description provided for @debugLog.
  ///
  /// In zh, this message translates to:
  /// **'事件日志'**
  String get debugLog;

  /// No description provided for @debugLogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志，播放一首歌试试。'**
  String get debugLogEmpty;

  /// No description provided for @debugCopyLog.
  ///
  /// In zh, this message translates to:
  /// **'复制日志'**
  String get debugCopyLog;

  /// No description provided for @debugCopied.
  ///
  /// In zh, this message translates to:
  /// **'日志已复制到剪贴板'**
  String get debugCopied;

  /// No description provided for @debugStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get debugStatus;

  /// No description provided for @debugPlaying.
  ///
  /// In zh, this message translates to:
  /// **'播放中'**
  String get debugPlaying;

  /// No description provided for @debugPosition.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get debugPosition;

  /// No description provided for @debugDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get debugDuration;

  /// No description provided for @debugVolume.
  ///
  /// In zh, this message translates to:
  /// **'音量'**
  String get debugVolume;

  /// No description provided for @debugIndex.
  ///
  /// In zh, this message translates to:
  /// **'当前索引'**
  String get debugIndex;

  /// No description provided for @debugQueueLen.
  ///
  /// In zh, this message translates to:
  /// **'队列长度'**
  String get debugQueueLen;

  /// No description provided for @debugActive.
  ///
  /// In zh, this message translates to:
  /// **'会话激活'**
  String get debugActive;

  /// No description provided for @debugOutputDevices.
  ///
  /// In zh, this message translates to:
  /// **'输出设备'**
  String get debugOutputDevices;

  /// No description provided for @debugSessionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get debugSessionUnknown;

  /// No description provided for @debugOutputDeviceDefault.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统默认'**
  String get debugOutputDeviceDefault;

  /// No description provided for @debugOutputDeviceApplied.
  ///
  /// In zh, this message translates to:
  /// **'输出设备：{name}'**
  String debugOutputDeviceApplied(Object name);

  /// No description provided for @debugOutputDeviceFailed.
  ///
  /// In zh, this message translates to:
  /// **'切换输出设备失败'**
  String get debugOutputDeviceFailed;

  /// No description provided for @addServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get addServerTitle;

  /// No description provided for @lanDiscovery.
  ///
  /// In zh, this message translates to:
  /// **'局域网探索'**
  String get lanDiscovery;

  /// No description provided for @lanRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新局域网搜索'**
  String get lanRefresh;

  /// No description provided for @searchingLan.
  ///
  /// In zh, this message translates to:
  /// **'正在搜索局域网中的音乐服务器…'**
  String get searchingLan;

  /// No description provided for @noServersFound.
  ///
  /// In zh, this message translates to:
  /// **'未发现任何服务器'**
  String get noServersFound;

  /// No description provided for @ensureSameNetwork.
  ///
  /// In zh, this message translates to:
  /// **'请确认设备处于同一局域网'**
  String get ensureSameNetwork;

  /// No description provided for @manualAdd.
  ///
  /// In zh, this message translates to:
  /// **'手动添加'**
  String get manualAdd;

  /// No description provided for @comingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将支持'**
  String get comingSoon;

  /// No description provided for @artistCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 位艺术家'**
  String artistCount(int count);

  /// No description provided for @artistSongCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 首歌曲'**
  String artistSongCount(int count);

  /// No description provided for @similarArtists.
  ///
  /// In zh, this message translates to:
  /// **'相似艺术家'**
  String get similarArtists;

  /// No description provided for @artistBio.
  ///
  /// In zh, this message translates to:
  /// **'关于艺术家'**
  String get artistBio;

  /// No description provided for @viewGrid.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get viewGrid;

  /// No description provided for @viewList.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get viewList;

  /// No description provided for @sortNameAsc.
  ///
  /// In zh, this message translates to:
  /// **'名称 (A-Z)'**
  String get sortNameAsc;

  /// No description provided for @sortNameDesc.
  ///
  /// In zh, this message translates to:
  /// **'名称 (Z-A)'**
  String get sortNameDesc;

  /// No description provided for @sortAlbumCount.
  ///
  /// In zh, this message translates to:
  /// **'专辑数量'**
  String get sortAlbumCount;

  /// No description provided for @sortYearDesc.
  ///
  /// In zh, this message translates to:
  /// **'发行年份 (最新)'**
  String get sortYearDesc;

  /// No description provided for @sortYearAsc.
  ///
  /// In zh, this message translates to:
  /// **'发行年份 (最早)'**
  String get sortYearAsc;

  /// No description provided for @showMore.
  ///
  /// In zh, this message translates to:
  /// **'展开更多'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get showLess;

  /// No description provided for @noSimilarArtists.
  ///
  /// In zh, this message translates to:
  /// **'暂无相似艺术家'**
  String get noSimilarArtists;

  /// No description provided for @filterArtistsHint.
  ///
  /// In zh, this message translates to:
  /// **'过滤艺术家...'**
  String get filterArtistsHint;

  /// No description provided for @discography.
  ///
  /// In zh, this message translates to:
  /// **'音乐作品'**
  String get discography;

  /// No description provided for @playbackSpeed.
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get playbackSpeed;

  /// No description provided for @speedNormal.
  ///
  /// In zh, this message translates to:
  /// **'标准 (1.0x)'**
  String get speedNormal;

  /// No description provided for @endOfSong.
  ///
  /// In zh, this message translates to:
  /// **'播完当前歌曲后关闭'**
  String get endOfSong;

  /// No description provided for @coverView.
  ///
  /// In zh, this message translates to:
  /// **'封面'**
  String get coverView;

  /// No description provided for @lyricsView.
  ///
  /// In zh, this message translates to:
  /// **'歌词模式'**
  String get lyricsView;

  /// No description provided for @oledLyricsView.
  ///
  /// In zh, this message translates to:
  /// **'纯黑歌词'**
  String get oledLyricsView;

  /// No description provided for @songInfo.
  ///
  /// In zh, this message translates to:
  /// **'歌曲信息'**
  String get songInfo;

  /// No description provided for @trackDetails.
  ///
  /// In zh, this message translates to:
  /// **'曲目详情'**
  String get trackDetails;

  /// No description provided for @trackInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get trackInfoTitle;

  /// No description provided for @trackInfoArtist.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get trackInfoArtist;

  /// No description provided for @trackInfoAlbum.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get trackInfoAlbum;

  /// No description provided for @trackInfoDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get trackInfoDuration;

  /// No description provided for @trackInfoId.
  ///
  /// In zh, this message translates to:
  /// **'音轨 ID'**
  String get trackInfoId;

  /// No description provided for @audioQuality.
  ///
  /// In zh, this message translates to:
  /// **'音质'**
  String get audioQuality;

  /// No description provided for @cancelSleepTimer.
  ///
  /// In zh, this message translates to:
  /// **'取消定时关闭'**
  String get cancelSleepTimer;

  /// No description provided for @sleepTimerCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消定时关闭'**
  String get sleepTimerCancelled;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
