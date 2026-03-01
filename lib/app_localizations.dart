import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  throw UnimplementedError(
      'appLocalizationsProvider must be overridden in ProviderScope');
});

class AppLocalizations {
  final Locale _locale;
  Locale get locale => _locale;

  AppLocalizations(this._locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'login': 'Login',
      'signup': 'Sign up',
      'email': 'Enter your email',
      'password': 'Enter your password',
      'name': 'Enter your full name',
      'phone': 'Enter your Phone number',
      'userType': 'User Type',
      'driver': 'Driver',
      'cargo': 'Cargo',
      'truckType': 'Select truck type',
      'alreadyAccount': 'Already have an account? ',
      'dontAccount': "Don't have an account yet? ",
      'post': 'Post',
      'cancel': 'Cancel',
      'newLoad': 'New Load',
      'feed': 'Feed',
      'search': 'Search',
      'forgotPassword': 'Forgot password',
      'editProfile': 'Edit Profile',
      'done': 'Done',
      'bids': 'BIDS ',
      'bidNow': 'BID NOW',
      'reply': 'Reply',
      'postComment': 'Post',
      'accept': 'Accept',
      'delpost': 'Delete Post',
      'suredelpost': 'Are you sure you want to delete this post?',
      'yes': 'Yes',
      'no': 'No',
      'DEP': 'Origin',
      'DEST': 'Destination',
      'WEIGHT': 'WEIGHT',
      'TYPE': 'TYPE',
      'PACKAGING': 'PACKAGING',
      'myLoads': 'My Loads',
      'activeLoads': 'Active Loads',
      'availableLoads': 'Available Loads',
      'noLoadsPosted': 'No posted loads yet.',
      'noLoadsAvailable': 'No loads available.',
      'status': 'Status',
      'from': 'From',
      'to': 'To',
      'retry': 'Retry',
      'refresh': 'Refresh',
      'acceptedCarriers': 'Accepted Carriers',
      'manage': 'Manage',
      'currentStatus': 'Current Status',
      'timeline': 'Timeline',
      'timeUnavailable': 'time unavailable',
      'justNow': 'Just Now',
      'ago': 'ago',
      'yesterday': 'Yesterday',
      'Jan': 'Jan',
      'Feb': 'Feb',
      'Mar': 'Mar',
      'Apr': 'Apr',
      'May': 'May',
      'Jun': 'Jun',
      'Jul': 'Jul',
      'Aug': 'Aug',
      'Sep': 'Sep',
      'Oct': 'Oct',
      'Nov': 'Nov',
      'Dec': 'Dec',

      // ...add more as needed
    },
    'om': {
      'login': 'Login',
      'signup': 'Akawntii bana',
      'email': 'Imelii kee galchi',
      'password': 'Paswordii kee galchi',
      'name': 'Maqaa kee galchi',
      'phone': 'Telefoonii kee galchi',
      'userType': 'Meeshaa moo Konkolaataa qabduu?',
      'driver': 'Konkolaataa kan qabu',
      'cargo': 'Mesha kan qabu',
      'truckType': 'Gosa konkolaataa filadhu',
      'alreadyAccount': 'Akkawotii qabduu? ',
      'dontAccount': 'Akkawotii hin qabduu? ',
      'post': 'Maxxansi',
      'cancel': 'Dhiisi',
      'newLoad': 'Fe’umsaa Haaraa',
      'feed': 'Feedii',
      'search': 'Barbaadi',
      'forgotPassword': 'Paswordii Irranfadhe',
      'editProfile': 'Piroofaayilii Gulaali',
      'done': 'Xumurame',
      'bids': 'Baayina caalbaasii:',
      'bidNow': 'Caalbaasii',
      'reply': 'Deebisi',
      'postComment': 'Maxxansi',
      'accept': 'Fudhadhu',
      'delpost': 'Postii kana haqi',
      'suredelpost': 'Postii kana haquu barbaaddu?',
      'yes': 'Eeyyee',
      'no': 'Lakki',
      'DEP': 'Bakka Kaumsaa',
      'DEST': 'Iddoo deemu',
      'WEIGHT': 'Ulfaatina',
      'TYPE': 'Gosa',
      'PACKAGING': 'Qophii',
      'myLoads': 'My Loads',
      'activeLoads': 'Active Loads',
      'availableLoads': 'Available Loads',
      'noLoadsPosted': 'No posted loads yet.',
      'noLoadsAvailable': 'No loads available.',
      'status': 'Status',
      'from': 'From',
      'to': 'To',
      'retry': 'Retry',
      'refresh': 'Refresh',
      'acceptedCarriers': 'Accepted Carriers',
      'manage': 'Manage',
      'currentStatus': 'Current Status',
      'timeline': 'Timeline',
      'timeUnavailable': 'time unavailable',
      'justNow': 'Amma',
      'ago': 'Dura',
      'yesterday': 'Kaleessa',
      'Jan': 'Ama',
      'Feb': 'Gur',
      'Mar': 'Bit',
      'Apr': 'Ebla',
      'May': 'Cam',
      'Jun': 'Wax',
      'Jul': 'Ado',
      'Aug': 'Hag',
      'Sep': 'Ful',
      'Oct': 'Onk',
      'Nov': 'Sad',
      'Dec': 'Mud',

      // ...add more as needed
    },
    'am': {
      'login': 'Login',
      'signup': 'መመዝገብ',
      'email': 'ኢሜይልዎን ያስገቡ',
      'password': 'የይለፍ ቃል ያስገቡ',
      'name': 'ሙሉ ስምዎን ያስገቡ',
      'phone': 'ስልክ ቁጥርዎን ያስገቡ',
      'userType': 'የተጠቃሚ አይነት',
      'driver': 'መኪና ያለው',
      'cargo': 'የሚጓጓዝ ጭነት ያለው',
      'truckType': 'የተሸከርካሪ አይነት ይምረጡ',
      'alreadyAccount': 'አካውንት አለዎት?',
      'dontAccount': 'አካውንት አልከፈቱም?',
      'post': 'ለጥፍ',
      'cancel': 'ሰርዝ',
      'newLoad': 'አዲስ ጭነት',
      'feed': 'መጠቀሚያ',
      'search': 'ፈልግ',
      'forgotPassword': 'የይለፍ ቃል አስታውሱም',
      'editProfile': 'መገለጫ አስተካክል',
      'done': 'ተጠናቀቀ',
      'bids': 'የተጫራቾች ብዛት:',
      'bidNow': 'አሁን ይጫረቱ',
      'reply': 'መልስ ስጥ',
      'postComment': 'ለጥፍ',
      'accept': 'ተቀበል',
      'delpost': 'ይህን ሰርዝ',
      'suredelpost': 'ይህን መሰረዝ ይፈልጋሉ?',
      'yes': 'አዎ',
      'no': 'አይ',
      'DEP': 'መነሻ ቦታ',
      'DEST': 'መድረሻ ቦታ',
      'WEIGHT': 'ክብደት',
      'TYPE': 'አይነት',
      'PACKAGING': 'መጠቀለያ',
      'myLoads': 'የእኔ ጭነቶች',
      'activeLoads': 'በሂደት ያሉ ጭነቶች',
      'availableLoads': 'ያሉ ጭነቶች',
      'noLoadsPosted': 'እስካሁን የተለጠፈ ጭነት የለም።',
      'noLoadsAvailable': 'ያለ ጭነት የለም።',
      'status': 'ሁኔታ',
      'from': 'ከ',
      'to': 'ወደ',
      'retry': 'ዳግም ሞክር',
      'refresh': 'አድስ',
      'acceptedCarriers': 'የተቀበሉ አጓጓዦች',
      'manage': 'አስተዳድር',
      'currentStatus': 'የአሁኑ ሁኔታ',
      'timeline': 'የሂደት ታሪክ',
      'timeUnavailable': 'ጊዜ አይገኝም',
      'justNow': 'አሁን',
      'ago': 'በፊት',
      'yesterday': 'ትናንት',
      'Jan': 'Jan',
      'Feb': 'Feb',
      'Mar': 'Mar',
      'Apr': 'Apr',
      'May': 'May',
      'Jun': 'Jun',
      'Jul': 'Jul',
      'Aug': 'Aug',
      'Sep': 'Sep',
      'Oct': 'Oct',
      'Nov': 'Nov',
      'Dec': 'Dec',
      // ...add more as needed
    }
  };

  String tr(String key) {
    return _localizedValues[_locale.languageCode]?[key] ?? key;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Add your supported locales here
    return ['en', 'am', 'om'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Implement your loading logic here
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// This file only provides localization utilities and the provider.