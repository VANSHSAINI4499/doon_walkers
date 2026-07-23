import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The app's icon set: **Material Symbols Rounded, filled only.**
///
/// Two hard rules for the whole redesign, enforced here so no screen has
/// to remember them:
///
///  1. **Rounded, never outlined or sharp.** Every constant in [AppIcons]
///     resolves to the `MaterialSymbolsRounded` font family. There is a
///     test (`test/core/icons/app_icons_test.dart`) that fails the build
///     if one slips through as outlined.
///  2. **Filled, never hollow.** Material Symbols is a *variable* font
///     with a `FILL` axis, so filled and hollow are the same glyph at a
///     different axis value — not two different [IconData]. That means
///     the fill has to be applied at render time, which is what [AppIcon]
///     exists for. Rendering `Icon(AppIcons.home)` directly would give
///     you the hollow form.
///
/// So: **always draw icons with [AppIcon], never with a bare [Icon].**
///
/// Flutter's `Icons.*` set (the old Material Icons font) is deliberately
/// not used anywhere in redesigned code. Screens still on `Icons.*` are
/// pre-redesign and get migrated in their own phase.
///
/// ## Adding an icon
///
/// Look the name up at fonts.google.com/icons, then add
/// `static const IconData foo = Symbols.foo_rounded;` in the right
/// section below. Keep this list curated: it is the app's icon
/// vocabulary, and a short vocabulary is what makes an icon set feel
/// designed.
abstract final class AppIcons {
  // ── Navigation & chrome ───────────────────────────────────────────
  static const IconData home = Symbols.home_rounded;
  static const IconData treks = Symbols.terrain_rounded;
  static const IconData challenges = Symbols.emoji_events_rounded;
  static const IconData profile = Symbols.person_rounded;
  static const IconData registrations = Symbols.groups_rounded;
  static const IconData menu = Symbols.menu_rounded;
  static const IconData more = Symbols.more_vert_rounded;
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData forward = Symbols.arrow_forward_rounded;
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData search = Symbols.search_rounded;
  static const IconData searchOff = Symbols.search_off_rounded;
  static const IconData filter = Symbols.tune_rounded;
  static const IconData sort = Symbols.sort_rounded;
  static const IconData openExternal = Symbols.open_in_new_rounded;
  static const IconData share = Symbols.share_rounded;
  static const IconData refresh = Symbols.refresh_rounded;

  // ── Trek & outdoors ───────────────────────────────────────────────
  static const IconData hiking = Symbols.hiking_rounded;
  static const IconData walk = Symbols.directions_walk_rounded;
  static const IconData run = Symbols.directions_run_rounded;
  static const IconData explore = Symbols.explore_rounded;
  static const IconData landscape = Symbols.landscape_rounded;
  static const IconData altitude = Symbols.filter_hdr_rounded;
  static const IconData distance = Symbols.straighten_rounded;
  static const IconData duration = Symbols.timer_rounded;
  static const IconData difficulty = Symbols.signal_cellular_alt_rounded;
  static const IconData season = Symbols.wb_sunny_rounded;
  static const IconData packing = Symbols.backpack_rounded;
  static const IconData map = Symbols.map_rounded;
  static const IconData flag = Symbols.flag_rounded;

  // ── Activity & achievement ────────────────────────────────────────
  static const IconData streak = Symbols.local_fire_department_rounded;
  static const IconData steps = Symbols.footprint_rounded;
  static const IconData leaderboard = Symbols.leaderboard_rounded;
  static const IconData insights = Symbols.insights_rounded;
  static const IconData trending = Symbols.trending_up_rounded;
  static const IconData medal = Symbols.military_tech_rounded;
  static const IconData premium = Symbols.workspace_premium_rounded;
  static const IconData celebrate = Symbols.celebration_rounded;
  static const IconData bolt = Symbols.bolt_rounded;
  static const IconData star = Symbols.star_rounded;
  static const IconData favorite = Symbols.favorite_rounded;
  static const IconData verified = Symbols.verified_rounded;
  static const IconData taskDone = Symbols.task_alt_rounded;

  // ── People & community ────────────────────────────────────────────
  static const IconData person = Symbols.person_rounded;
  static const IconData group = Symbols.groups_rounded;
  static const IconData groupAdd = Symbols.group_add_rounded;
  static const IconData comment = Symbols.chat_rounded;
  static const IconData forum = Symbols.forum_rounded;
  static const IconData speaker = Symbols.record_voice_over_rounded;
  static const IconData wave = Symbols.emoji_people_rounded;
  static const IconData connect = Symbols.connect_without_contact_rounded;

  // ── Registration & forms ──────────────────────────────────────────
  static const IconData ticket = Symbols.confirmation_number_rounded;
  static const IconData calendar = Symbols.calendar_month_rounded;
  static const IconData eventAvailable = Symbols.event_available_rounded;
  static const IconData eventBusy = Symbols.event_busy_rounded;
  static const IconData schedule = Symbols.schedule_rounded;
  static const IconData emergencyContact = Symbols.contact_emergency_rounded;
  static const IconData medical = Symbols.medical_information_rounded;
  static const IconData safety = Symbols.health_and_safety_rounded;
  static const IconData birthday = Symbols.cake_rounded;
  static const IconData phone = Symbols.phone_rounded;
  static const IconData call = Symbols.call_rounded;
  static const IconData email = Symbols.mail_rounded;
  static const IconData emailRead = Symbols.mark_email_read_rounded;

  // ── Payment & merch ───────────────────────────────────────────────
  static const IconData rupee = Symbols.currency_rupee_rounded;
  static const IconData payment = Symbols.payments_rounded;
  static const IconData wallet = Symbols.wallet_rounded;
  static const IconData qr = Symbols.qr_code_2_rounded;
  static const IconData store = Symbols.storefront_rounded;
  static const IconData bag = Symbols.shopping_bag_rounded;
  static const IconData cart = Symbols.shopping_cart_rounded;
  static const IconData inventory = Symbols.inventory_2_rounded;

  // ── Media ─────────────────────────────────────────────────────────
  static const IconData photo = Symbols.photo_library_rounded;
  static const IconData image = Symbols.image_rounded;
  static const IconData imageBroken = Symbols.broken_image_rounded;
  static const IconData camera = Symbols.camera_alt_rounded;
  static const IconData cameraBack = Symbols.photo_camera_back_rounded;
  static const IconData addPhoto = Symbols.add_photo_alternate_rounded;
  static const IconData video = Symbols.videocam_rounded;
  static const IconData play = Symbols.play_arrow_rounded;
  static const IconData upload = Symbols.upload_file_rounded;
  static const IconData download = Symbols.download_rounded;

  // ── Actions & state ───────────────────────────────────────────────
  static const IconData add = Symbols.add_rounded;
  static const IconData edit = Symbols.edit_rounded;
  static const IconData editNote = Symbols.edit_note_rounded;
  static const IconData delete = Symbols.delete_rounded;
  static const IconData check = Symbols.check_rounded;
  static const IconData checkCircle = Symbols.check_circle_rounded;
  static const IconData removeCircle = Symbols.remove_circle_rounded;
  static const IconData block = Symbols.block_rounded;
  static const IconData rule = Symbols.rule_rounded;
  static const IconData send = Symbols.send_rounded;
  static const IconData sync = Symbols.sync_rounded;
  static const IconData info = Symbols.info_rounded;
  static const IconData error = Symbols.error_rounded;
  static const IconData notifications = Symbols.notifications_rounded;
  static const IconData announce = Symbols.campaign_rounded;
  static const IconData lock = Symbols.lock_rounded;
  static const IconData lockReset = Symbols.lock_reset_rounded;
  static const IconData logout = Symbols.logout_rounded;
  static const IconData visible = Symbols.visibility_rounded;
  static const IconData hidden = Symbols.visibility_off_rounded;
  static const IconData book = Symbols.menu_book_rounded;
  static const IconData desktop = Symbols.desktop_windows_rounded;

  /// Every icon in the vocabulary, for the "rounded family" invariant
  /// test and for the design-system demo screen's icon grid.
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
  };

  /// The font family every [AppIcons] entry must resolve to.
  static const String fontFamily = 'MaterialSymbolsRounded';
}

/// Draws an [AppIcons] symbol **filled**.
///
/// Material Symbols is a variable font: `FILL` is an axis from 0 (hollow)
/// to 1 (solid) on the *same* glyph, applied at render time. A plain
/// `Icon(AppIcons.home)` therefore renders the hollow outline — which the
/// design system does not allow anywhere. [AppIcon] pins `fill` to 1 so
/// that's impossible by construction.
///
/// [fill] is still exposed, for exactly one legitimate case: animating
/// the axis between 0 and 1 (a "tap to favourite" pop, a nav tab
/// crossfading on selection). Passing a static `fill: 0` to get an
/// outlined icon is a design-system violation, not a feature.
///
/// [weight], [grade] and [opticalSize] are the font's other axes. The
/// defaults here (600 weight, slightly positive grade) are tuned to sit
/// alongside Plus Jakarta Sans' bold headings without looking spindly on
/// a dark background — light-on-dark text optically thins, which is what
/// `GRAD` compensates for.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.fill = 1,
    this.weight = 600,
    this.grade = 25,
    this.opticalSize,
    this.semanticLabel,
  });

  /// A constant from [AppIcons].
  final IconData icon;
  final double size;
  final Color? color;

  /// The variable font's `FILL` axis, 0–1. Leave at 1 unless animating.
  final double fill;

  /// The `wght` axis, 100–700.
  final double weight;

  /// The `GRAD` axis, -50–200. Positive values thicken strokes slightly
  /// without changing the glyph's width — the right fix for light-on-dark.
  final double grade;

  /// The `opsz` axis, 20–48. Defaults to [size] so the glyph's stroke
  /// contrast is tuned to the size it's actually drawn at.
  final double? opticalSize;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size,
    color: color,
    fill: fill,
    weight: weight,
    grade: grade,
    opticalSize: opticalSize ?? size.clamp(20, 48),
    semanticLabel: semanticLabel,
  );
}
