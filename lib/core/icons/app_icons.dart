import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's central icon set: **Lucide Icons**.
abstract final class AppIcons {
  // ── Navigation & chrome ───────────────────────────────────────────
  static const IconData home = LucideIcons.house;
  static const IconData treks = LucideIcons.mountain;
  static const IconData challenges = LucideIcons.target;
  static const IconData profile = LucideIcons.userRound;
  static const IconData registrations = LucideIcons.users;
  static const IconData menu = LucideIcons.menu;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData forward = LucideIcons.arrowRight;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData close = LucideIcons.x;
  static const IconData search = LucideIcons.search;
  static const IconData searchOff = LucideIcons.searchX;
  static const IconData filter = LucideIcons.slidersHorizontal;
  static const IconData sort = LucideIcons.arrowUpDown;
  static const IconData openExternal = LucideIcons.externalLink;
  static const IconData share = LucideIcons.share2;
  static const IconData refresh = LucideIcons.refreshCw;

  // ── Trek & outdoors ───────────────────────────────────────────────
  static const IconData hiking = LucideIcons.footprints;
  static const IconData walk = LucideIcons.footprints;
  static const IconData run = LucideIcons.zap;
  static const IconData explore = LucideIcons.compass;
  static const IconData landscape = LucideIcons.mountainSnow;
  static const IconData altitude = LucideIcons.trendingUp;
  static const IconData distance = LucideIcons.ruler;
  static const IconData duration = LucideIcons.clock3;
  static const IconData difficulty = LucideIcons.mountain;
  static const IconData season = LucideIcons.sun;
  static const IconData packing = LucideIcons.backpack;
  static const IconData map = LucideIcons.map;
  static const IconData flag = LucideIcons.flag;

  // ── Activity & achievement ────────────────────────────────────────
  static const IconData streak = LucideIcons.flame;
  static const IconData steps = LucideIcons.footprints;
  static const IconData calories = LucideIcons.flame;
  static const IconData leaderboard = LucideIcons.trophy;
  static const IconData insights = LucideIcons.chartLine;
  static const IconData trending = LucideIcons.trendingUp;
  static const IconData trendingDown = LucideIcons.trendingDown;
  static const IconData medal = LucideIcons.medal;
  static const IconData premium = LucideIcons.award;
  static const IconData celebrate = LucideIcons.sparkles;
  static const IconData bolt = LucideIcons.zap;
  static const IconData star = LucideIcons.star;
  static const IconData favorite = LucideIcons.heart;
  static const IconData verified = LucideIcons.badgeCheck;
  static const IconData taskDone = LucideIcons.circleCheck;

  // ── People & community ────────────────────────────────────────────
  static const IconData person = LucideIcons.user;
  static const IconData group = LucideIcons.users;
  static const IconData groupAdd = LucideIcons.userPlus;
  static const IconData comment = LucideIcons.messageCircle;
  static const IconData forum = LucideIcons.messagesSquare;
  static const IconData speaker = LucideIcons.megaphone;
  static const IconData wave = LucideIcons.hand;
  static const IconData connect = LucideIcons.userCheck;

  // ── Registration & forms ──────────────────────────────────────────
  static const IconData ticket = LucideIcons.ticket;
  static const IconData calendar = LucideIcons.calendarDays;
  static const IconData eventAvailable = LucideIcons.calendarCheck;
  static const IconData eventBusy = LucideIcons.calendarX;
  static const IconData schedule = LucideIcons.clock;
  static const IconData emergencyContact = LucideIcons.phoneCall;
  static const IconData medical = LucideIcons.stethoscope;
  static const IconData safety = LucideIcons.shieldCheck;
  static const IconData birthday = LucideIcons.cake;
  static const IconData phone = LucideIcons.phone;
  static const IconData call = LucideIcons.phoneCall;
  static const IconData email = LucideIcons.mail;
  static const IconData emailRead = LucideIcons.mailCheck;

  // ── Payment & merch ───────────────────────────────────────────────
  static const IconData rupee = LucideIcons.indianRupee;
  static const IconData payment = LucideIcons.creditCard;
  static const IconData wallet = LucideIcons.wallet;
  static const IconData qr = LucideIcons.qrCode;
  static const IconData store = LucideIcons.store;
  static const IconData bag = LucideIcons.shoppingBag;
  static const IconData cart = LucideIcons.shoppingCart;
  static const IconData inventory = LucideIcons.package;

  // ── Media ─────────────────────────────────────────────────────────
  static const IconData photo = LucideIcons.images;
  static const IconData image = LucideIcons.image;
  static const IconData imageBroken = LucideIcons.imageOff;
  static const IconData camera = LucideIcons.camera;
  static const IconData cameraBack = LucideIcons.camera;
  static const IconData addPhoto = LucideIcons.imagePlus;
  static const IconData video = LucideIcons.video;
  static const IconData play = LucideIcons.play;
  static const IconData upload = LucideIcons.upload;
  static const IconData download = LucideIcons.download;

  // ── Actions & state ───────────────────────────────────────────────
  static const IconData add = LucideIcons.plus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData editNote = LucideIcons.notebookPen;
  static const IconData delete = LucideIcons.trash2;
  static const IconData check = LucideIcons.check;
  static const IconData checkCircle = LucideIcons.circleCheck;
  static const IconData removeCircle = LucideIcons.circleMinus;
  static const IconData block = LucideIcons.ban;
  static const IconData rule = LucideIcons.shieldAlert;
  static const IconData send = LucideIcons.send;
  static const IconData sync = LucideIcons.refreshCw;
  static const IconData info = LucideIcons.info;
  static const IconData error = LucideIcons.alertCircle;
  static const IconData notifications = LucideIcons.bell;
  static const IconData announce = LucideIcons.megaphone;
  static const IconData lock = LucideIcons.lock;
  static const IconData lockReset = LucideIcons.keyRound;
  static const IconData logout = LucideIcons.logOut;
  static const IconData visible = LucideIcons.eye;
  static const IconData hidden = LucideIcons.eyeOff;
  static const IconData book = LucideIcons.bookOpen;
  static const IconData desktop = LucideIcons.monitor;
  static const IconData cloudOff = LucideIcons.cloudOff;

  // ── Drawer destinations ───────────────────────────────────────────
  static const IconData settings = LucideIcons.settings;
  static const IconData support = LucideIcons.circleHelp;

  // ── Appearance ────────────────────────────────────────────────────
  static const IconData themeSystem = LucideIcons.monitor;
  static const IconData themeLight = LucideIcons.sun;
  static const IconData themeDark = LucideIcons.moon;

  /// Every icon in the vocabulary.
  static const Map<String, IconData> all = {
    'home': home,
    'treks': treks,
    'challenges': challenges,
    'profile': profile,
    'registrations': registrations,
    'menu': menu,
    'more': more,
    'back': back,
    'forward': forward,
    'chevronRight': chevronRight,
    'close': close,
    'search': search,
    'searchOff': searchOff,
    'filter': filter,
    'sort': sort,
    'openExternal': openExternal,
    'share': share,
    'refresh': refresh,
    'hiking': hiking,
    'walk': walk,
    'run': run,
    'explore': explore,
    'landscape': landscape,
    'altitude': altitude,
    'distance': distance,
    'duration': duration,
    'difficulty': difficulty,
    'season': season,
    'packing': packing,
    'map': map,
    'flag': flag,
    'streak': streak,
    'steps': steps,
    'calories': calories,
    'trendingDown': trendingDown,
    'leaderboard': leaderboard,
    'insights': insights,
    'trending': trending,
    'medal': medal,
    'premium': premium,
    'celebrate': celebrate,
    'bolt': bolt,
    'star': star,
    'favorite': favorite,
    'verified': verified,
    'taskDone': taskDone,
    'person': person,
    'group': group,
    'groupAdd': groupAdd,
    'comment': comment,
    'forum': forum,
    'speaker': speaker,
    'wave': wave,
    'connect': connect,
    'ticket': ticket,
    'calendar': calendar,
    'eventAvailable': eventAvailable,
    'eventBusy': eventBusy,
    'schedule': schedule,
    'emergencyContact': emergencyContact,
    'medical': medical,
    'safety': safety,
    'birthday': birthday,
    'phone': phone,
    'call': call,
    'email': email,
    'emailRead': emailRead,
    'rupee': rupee,
    'payment': payment,
    'wallet': wallet,
    'qr': qr,
    'store': store,
    'bag': bag,
    'cart': cart,
    'inventory': inventory,
    'photo': photo,
    'image': image,
    'imageBroken': imageBroken,
    'camera': camera,
    'cameraBack': cameraBack,
    'addPhoto': addPhoto,
    'video': video,
    'play': play,
    'upload': upload,
    'download': download,
    'add': add,
    'edit': edit,
    'editNote': editNote,
    'delete': delete,
    'check': check,
    'checkCircle': checkCircle,
    'removeCircle': removeCircle,
    'block': block,
    'rule': rule,
    'send': send,
    'sync': sync,
    'info': info,
    'error': error,
    'notifications': notifications,
    'announce': announce,
    'lock': lock,
    'lockReset': lockReset,
    'logout': logout,
    'visible': visible,
    'hidden': hidden,
    'book': book,
    'desktop': desktop,
    'settings': settings,
    'support': support,
    'themeSystem': themeSystem,
    'themeLight': themeLight,
    'themeDark': themeDark,
    'cloudOff': cloudOff,
  };
}

/// Draws an [AppIcons] symbol using Lucide Icons.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
    double? fill,
    double? weight,
    double? grade,
    double? opticalSize,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
}
