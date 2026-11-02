import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get commonRestore;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonError(Object error);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not3 {version} · your notes are stored on this device'**
  String settingsSubtitle(Object version);

  /// No description provided for @settingsSectionDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get settingsSectionDrive;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionFiles.
  ///
  /// In en, this message translates to:
  /// **'Backups and files'**
  String get settingsSectionFiles;

  /// No description provided for @settingsSectionTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get settingsSectionTools;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import .inklus or backup'**
  String get settingsImportTitle;

  /// No description provided for @settingsImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A notebook (.inklus) or a full backup (.zip); detected automatically'**
  String get settingsImportSubtitle;

  /// No description provided for @settingsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export full backup'**
  String get settingsExportTitle;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All notebooks, images and trash in one .zip'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsAutosaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Autosave'**
  String get settingsAutosaveTitle;

  /// No description provided for @settingsAutosaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every change is saved instantly on this device. A version is kept each time you open and close a note (⋮ menu → Version history).'**
  String get settingsAutosaveSubtitle;

  /// No description provided for @settingsStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Writing statistics'**
  String get settingsStatsTitle;

  /// No description provided for @settingsStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Strokes, pages, streaks and activity'**
  String get settingsStatsSubtitle;

  /// No description provided for @settingsRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsRemindersTitle;

  /// No description provided for @settingsRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts linked to your notebooks'**
  String get settingsRemindersSubtitle;

  /// No description provided for @settingsTrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get settingsTrashTitle;

  /// No description provided for @settingsTrashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recover deleted notebooks and notes'**
  String get settingsTrashSubtitle;

  /// No description provided for @settingsAppTagline.
  ///
  /// In en, this message translates to:
  /// **'Handwriting for stylus tablets'**
  String get settingsAppTagline;

  /// No description provided for @settingsFreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Free and open'**
  String get settingsFreeTitle;

  /// No description provided for @settingsFreeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open source (GPL-3.0). No paid features, no ads and no analytics.'**
  String get settingsFreeSubtitle;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What data the app handles and where it goes'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get settingsSourceTitle;

  /// No description provided for @settingsSourceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report a bug or suggest improvements on GitHub'**
  String get settingsSourceSubtitle;

  /// No description provided for @settingsErrorLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Error log'**
  String get settingsErrorLogTitle;

  /// No description provided for @settingsErrorLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stored only on this device; you can share it to help fix a bug'**
  String get settingsErrorLogSubtitle;

  /// No description provided for @settingsErrorLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No errors recorded'**
  String get settingsErrorLogEmpty;

  /// No description provided for @settingsErrorLogCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 error recorded} other{{count} errors recorded}}'**
  String settingsErrorLogCount(num count);

  /// No description provided for @settingsErrorLogShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'By email or in a GitHub issue'**
  String get settingsErrorLogShareSubtitle;

  /// No description provided for @settingsErrorLogClear.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get settingsErrorLogClear;

  /// No description provided for @settingsErrorLogCleared.
  ///
  /// In en, this message translates to:
  /// **'Log cleared'**
  String get settingsErrorLogCleared;

  /// No description provided for @settingsErrorLogSubject.
  ///
  /// In en, this message translates to:
  /// **'Not3 {version} error log'**
  String settingsErrorLogSubject(Object version);

  /// No description provided for @settingsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String settingsOpenFailed(Object url);

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @driveConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get driveConnected;

  /// No description provided for @driveCloudCopy.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get driveCloudCopy;

  /// No description provided for @driveGoogleAccount.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get driveGoogleAccount;

  /// No description provided for @driveOptionalPitch.
  ///
  /// In en, this message translates to:
  /// **'Optional: keep a copy of your notes in your Google Drive'**
  String get driveOptionalPitch;

  /// No description provided for @driveConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get driveConnect;

  /// No description provided for @driveUploadNow.
  ///
  /// In en, this message translates to:
  /// **'Upload now'**
  String get driveUploadNow;

  /// No description provided for @driveUploadNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uploads the notes of notebooks with sync enabled'**
  String get driveUploadNowSubtitle;

  /// No description provided for @driveRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from Drive'**
  String get driveRestore;

  /// No description provided for @driveRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Brings the newest versions and recovers notes missing on this device'**
  String get driveRestoreSubtitle;

  /// No description provided for @driveNoteVersions.
  ///
  /// In en, this message translates to:
  /// **'Versions of a note'**
  String get driveNoteVersions;

  /// No description provided for @driveNoteVersionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In the editor: ⋮ → Version history'**
  String get driveNoteVersionsSubtitle;

  /// No description provided for @driveSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get driveSwitchAccount;

  /// No description provided for @driveSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get driveSignOut;

  /// No description provided for @driveAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get driveAccount;

  /// No description provided for @driveConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as {email}'**
  String driveConnectedAs(Object email);

  /// No description provided for @driveNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Google is not configured'**
  String get driveNotConfigured;

  /// No description provided for @driveSignOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get driveSignOutQuestion;

  /// No description provided for @driveSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'Backups will stop being uploaded to Google Drive. Copies already in Drive are kept.'**
  String get driveSignOutBody;

  /// No description provided for @driveSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get driveSignedOut;

  /// No description provided for @driveUploaded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No notebooks have sync enabled} =1{1 note uploaded to Drive} other{{count} notes uploaded to Drive}}'**
  String driveUploaded(num count);

  /// No description provided for @driveRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Notes on this device are only replaced if the Drive copy is newer. Notes missing here go back to their notebook (or to a new \"Recovered from Drive\" one).'**
  String get driveRestoreBody;

  /// No description provided for @backupSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Not3 backup'**
  String get backupSaveTitle;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @driveSignInIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not complete'**
  String get driveSignInIncomplete;

  /// No description provided for @driveDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get driveDetails;

  /// No description provided for @driveSignInHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in'**
  String get driveSignInHelpTitle;

  /// No description provided for @driveSignInHelpBody.
  ///
  /// In en, this message translates to:
  /// **'If you just closed the account picker, nothing is wrong. If you chose an account and it did not connect, the app\'s signing key (SHA-1) is almost always not registered in Google Cloud for io.github.pyrhomits.not3.\n\nTechnical detail:\n{details}'**
  String driveSignInHelpBody(Object details);

  /// No description provided for @driveNotebooksTitle.
  ///
  /// In en, this message translates to:
  /// **'Notebooks that sync'**
  String get driveNotebooksTitle;

  /// No description provided for @driveNotebooksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each notebook is saved in Drive → Not3 → its own folder. Choose which ones.'**
  String get driveNotebooksSubtitle;

  /// No description provided for @driveNotebooksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notebooks yet.'**
  String get driveNotebooksEmpty;

  /// No description provided for @driveSyncMenu.
  ///
  /// In en, this message translates to:
  /// **'Sync with Drive'**
  String get driveSyncMenu;

  /// No description provided for @driveSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sync enabled'**
  String get driveSyncEnabled;

  /// No description provided for @driveSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sync disabled'**
  String get driveSyncDisabled;

  /// No description provided for @textEditHint.
  ///
  /// In en, this message translates to:
  /// **'Type here…'**
  String get textEditHint;

  /// No description provided for @textEditMove.
  ///
  /// In en, this message translates to:
  /// **'Move box'**
  String get textEditMove;

  /// No description provided for @textEditWidth.
  ///
  /// In en, this message translates to:
  /// **'Box width'**
  String get textEditWidth;

  /// No description provided for @textEditSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get textEditSmaller;

  /// No description provided for @textEditLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get textEditLarger;

  /// No description provided for @textEditBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get textEditBold;

  /// No description provided for @textEditItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get textEditItalic;

  /// No description provided for @textEditUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get textEditUnderline;

  /// No description provided for @textEditStrike.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get textEditStrike;

  /// No description provided for @textEditColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get textEditColor;

  /// No description provided for @textEditHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get textEditHighlight;

  /// No description provided for @textEditAlign.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get textEditAlign;

  /// No description provided for @textEditSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get textEditSpacing;

  /// No description provided for @textEditLinkActive.
  ///
  /// In en, this message translates to:
  /// **'Page link (active)'**
  String get textEditLinkActive;

  /// No description provided for @textEditLink.
  ///
  /// In en, this message translates to:
  /// **'Link to page'**
  String get textEditLink;

  /// No description provided for @textEditDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete box'**
  String get textEditDelete;

  /// No description provided for @textEditDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get textEditDone;

  /// No description provided for @textEditWholeBox.
  ///
  /// In en, this message translates to:
  /// **'Whole box'**
  String get textEditWholeBox;

  /// No description provided for @textEditNoHighlight.
  ///
  /// In en, this message translates to:
  /// **'No highlight'**
  String get textEditNoHighlight;

  /// No description provided for @textEditUnlink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get textEditUnlink;

  /// No description provided for @commonPageN.
  ///
  /// In en, this message translates to:
  /// **'Page {n}'**
  String commonPageN(int n);

  /// No description provided for @marketWhereTemplate.
  ///
  /// In en, this message translates to:
  /// **'in the page\'s Template menu'**
  String get marketWhereTemplate;

  /// No description provided for @marketWherePalette.
  ///
  /// In en, this message translates to:
  /// **'in each pen\'s colors'**
  String get marketWherePalette;

  /// No description provided for @marketWhereStickers.
  ///
  /// In en, this message translates to:
  /// **'in More tools → Insert sticker'**
  String get marketWhereStickers;

  /// No description provided for @marketHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover and customize'**
  String get marketHeroTitle;

  /// No description provided for @marketHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Community templates, palettes and stickers. Free and openly licensed.'**
  String get marketHeroSubtitle;

  /// No description provided for @marketSearch.
  ///
  /// In en, this message translates to:
  /// **'Search packs'**
  String get marketSearch;

  /// No description provided for @marketTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketTitle;

  /// No description provided for @marketOfflineCache.
  ///
  /// In en, this message translates to:
  /// **'Offline: showing the last downloaded catalog'**
  String get marketOfflineCache;

  /// No description provided for @marketOfflineBundled.
  ///
  /// In en, this message translates to:
  /// **'Offline: showing packs bundled with the app'**
  String get marketOfflineBundled;

  /// No description provided for @marketAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get marketAll;

  /// No description provided for @marketTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get marketTemplates;

  /// No description provided for @marketPalettes.
  ///
  /// In en, this message translates to:
  /// **'Palettes'**
  String get marketPalettes;

  /// No description provided for @marketStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get marketStickers;

  /// No description provided for @marketPalette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get marketPalette;

  /// No description provided for @marketNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching packs'**
  String get marketNoResults;

  /// No description provided for @marketRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get marketRemove;

  /// No description provided for @marketInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get marketInstall;

  /// No description provided for @marketUninstalled.
  ///
  /// In en, this message translates to:
  /// **'“{name}” uninstalled'**
  String marketUninstalled(String name);

  /// No description provided for @marketInstalled.
  ///
  /// In en, this message translates to:
  /// **'“{name}” installed: {where}'**
  String marketInstalled(String name, String where);

  /// No description provided for @marketInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not install “{name}”: {error}'**
  String marketInstallFailed(String name, String error);

  /// No description provided for @createTplBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank'**
  String get createTplBlank;

  /// No description provided for @createTplRuled.
  ///
  /// In en, this message translates to:
  /// **'Ruled'**
  String get createTplRuled;

  /// No description provided for @createTplGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get createTplGrid;

  /// No description provided for @createTplDots.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get createTplDots;

  /// No description provided for @createTplMusic.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get createTplMusic;

  /// No description provided for @createTplPlanner.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get createTplPlanner;

  /// No description provided for @createTplHabit.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get createTplHabit;

  /// No description provided for @createTplSheet.
  ///
  /// In en, this message translates to:
  /// **'A4 sheet'**
  String get createTplSheet;

  /// No description provided for @createTitle.
  ///
  /// In en, this message translates to:
  /// **'New notebook'**
  String get createTitle;

  /// No description provided for @createName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get createName;

  /// No description provided for @createNameHint.
  ///
  /// In en, this message translates to:
  /// **'My notebook'**
  String get createNameHint;

  /// No description provided for @createCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get createCover;

  /// No description provided for @createDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get createDesign;

  /// No description provided for @createYourImage.
  ///
  /// In en, this message translates to:
  /// **'Your image'**
  String get createYourImage;

  /// No description provided for @createChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get createChangeImage;

  /// No description provided for @createColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get createColor;

  /// No description provided for @createNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get createNext;

  /// No description provided for @createStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2: choose a template'**
  String get createStep2;

  /// No description provided for @createBackToStep1.
  ///
  /// In en, this message translates to:
  /// **'Back to step 1'**
  String get createBackToStep1;

  /// No description provided for @createTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get createTemplate;

  /// No description provided for @createMoreTemplates.
  ///
  /// In en, this message translates to:
  /// **'Show more templates'**
  String get createMoreTemplates;

  /// No description provided for @createFewer.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get createFewer;

  /// No description provided for @createInfinite.
  ///
  /// In en, this message translates to:
  /// **'Infinite canvas'**
  String get createInfinite;

  /// No description provided for @createInfiniteOn.
  ///
  /// In en, this message translates to:
  /// **'The canvas grows as you write'**
  String get createInfiniteOn;

  /// No description provided for @createInfiniteOff.
  ///
  /// In en, this message translates to:
  /// **'Fixed-size sheet (A4)'**
  String get createInfiniteOff;

  /// No description provided for @createAction.
  ///
  /// In en, this message translates to:
  /// **'Create notebook'**
  String get createAction;

  /// No description provided for @createDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Notebook {n}'**
  String createDefaultName(int n);

  /// No description provided for @createCoverSemantics.
  ///
  /// In en, this message translates to:
  /// **'Cover {name}'**
  String createCoverSemantics(String name);

  /// No description provided for @libRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename notebook'**
  String get libRenameTitle;

  /// No description provided for @libDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete notebook'**
  String get libDeleteTitle;

  /// No description provided for @libDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get libDelete;

  /// No description provided for @libCoverColor.
  ///
  /// In en, this message translates to:
  /// **'Cover color'**
  String get libCoverColor;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @libSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort notebooks'**
  String get libSortTitle;

  /// No description provided for @libSortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get libSortNewestFirst;

  /// No description provided for @libSortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get libSortOldestFirst;

  /// No description provided for @libSortTitleAZ.
  ///
  /// In en, this message translates to:
  /// **'Title A → Z'**
  String get libSortTitleAZ;

  /// No description provided for @libSortTitleZA.
  ///
  /// In en, this message translates to:
  /// **'Title Z → A'**
  String get libSortTitleZA;

  /// No description provided for @libNavAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libNavAll;

  /// No description provided for @libNavRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get libNavRecent;

  /// No description provided for @libNavFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get libNavFavorites;

  /// No description provided for @libNavFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libNavFolders;

  /// No description provided for @libImport.
  ///
  /// In en, this message translates to:
  /// **'Import .inklus'**
  String get libImport;

  /// No description provided for @libTrash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get libTrash;

  /// No description provided for @libLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get libLightMode;

  /// No description provided for @libDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get libDarkMode;

  /// No description provided for @libMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get libMoreOptions;

  /// No description provided for @libMyNotebooks.
  ///
  /// In en, this message translates to:
  /// **'My notebooks'**
  String get libMyNotebooks;

  /// No description provided for @libClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get libClearFilter;

  /// No description provided for @libSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or tag'**
  String get libSearchHint;

  /// No description provided for @libSearchInNotes.
  ///
  /// In en, this message translates to:
  /// **'Search inside notes (text and handwriting)'**
  String get libSearchInNotes;

  /// No description provided for @libSearchContent.
  ///
  /// In en, this message translates to:
  /// **'In content'**
  String get libSearchContent;

  /// No description provided for @libSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get libSortNewest;

  /// No description provided for @libSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get libSortOldest;

  /// No description provided for @libSortNameAZ.
  ///
  /// In en, this message translates to:
  /// **'Name A–Z'**
  String get libSortNameAZ;

  /// No description provided for @libSortNameZA.
  ///
  /// In en, this message translates to:
  /// **'Name Z–A'**
  String get libSortNameZA;

  /// No description provided for @libGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get libGrid;

  /// No description provided for @libList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get libList;

  /// No description provided for @libNoResults.
  ///
  /// In en, this message translates to:
  /// **'No notebooks found'**
  String get libNoResults;

  /// No description provided for @libEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start writing'**
  String get libEmptyTitle;

  /// No description provided for @libNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try another name or tag.'**
  String get libNoResultsHint;

  /// No description provided for @libUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get libUnfavorite;

  /// No description provided for @libFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get libFavorite;

  /// No description provided for @libRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get libRename;

  /// No description provided for @libDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get libDuplicate;

  /// No description provided for @libCoverAndColor.
  ///
  /// In en, this message translates to:
  /// **'Cover and color'**
  String get libCoverAndColor;

  /// No description provided for @libTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get libTags;

  /// No description provided for @libSyncOff.
  ///
  /// In en, this message translates to:
  /// **'Stop syncing with Drive'**
  String get libSyncOff;

  /// No description provided for @libMoveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get libMoveToTrash;

  /// No description provided for @libNotebookOptions.
  ///
  /// In en, this message translates to:
  /// **'Notebook options'**
  String get libNotebookOptions;

  /// No description provided for @libSyncWillSync.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will sync with Drive'**
  String libSyncWillSync(String title);

  /// No description provided for @libSyncStopped.
  ///
  /// In en, this message translates to:
  /// **'“{title}” no longer syncs'**
  String libSyncStopped(String title);

  /// No description provided for @libDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be moved to the trash. You can restore it from there.'**
  String libDeleteBody(String title);

  /// No description provided for @libImportError.
  ///
  /// In en, this message translates to:
  /// **'Import error: {error}'**
  String libImportError(String error);

  /// No description provided for @libCountAll.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{1 notebook} other{{total} notebooks}}'**
  String libCountAll(int total);

  /// No description provided for @libCountOf.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} notebooks'**
  String libCountOf(int shown, int total);

  /// No description provided for @libNotebookSemantics.
  ///
  /// In en, this message translates to:
  /// **'Notebook {title}, {when}'**
  String libNotebookSemantics(String title, String when);

  /// No description provided for @libEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Create a new notebook or import an existing one\\nto get started.'**
  String get libEmptyHint;

  /// No description provided for @noteRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename note'**
  String get noteRenameTitle;

  /// No description provided for @noteDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get noteDeleteTitle;

  /// No description provided for @noteNew.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get noteNew;

  /// No description provided for @noteNameHint.
  ///
  /// In en, this message translates to:
  /// **'My note'**
  String get noteNameHint;

  /// No description provided for @noteCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get noteCreate;

  /// No description provided for @noteEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get noteEmptyTitle;

  /// No description provided for @noteEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Create your first note to start writing.'**
  String get noteEmptyHint;

  /// No description provided for @noteCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create note'**
  String get noteCreateAction;

  /// No description provided for @noteOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get noteOptions;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeNow;

  /// No description provided for @noteTplInfinite.
  ///
  /// In en, this message translates to:
  /// **'Infinite'**
  String get noteTplInfinite;

  /// No description provided for @noteTplSheet.
  ///
  /// In en, this message translates to:
  /// **'Fixed sheet'**
  String get noteTplSheet;

  /// No description provided for @noteTplPlanner.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get noteTplPlanner;

  /// No description provided for @tplInfiniteHint.
  ///
  /// In en, this message translates to:
  /// **'Infinite ones grow as you write'**
  String get tplInfiniteHint;

  /// No description provided for @tplNormalSheet.
  ///
  /// In en, this message translates to:
  /// **'Regular sheet'**
  String get tplNormalSheet;

  /// No description provided for @tplOwn.
  ///
  /// In en, this message translates to:
  /// **'Your own template'**
  String get tplOwn;

  /// No description provided for @tplFromMarket.
  ///
  /// In en, this message translates to:
  /// **'From the marketplace'**
  String get tplFromMarket;

  /// No description provided for @tplMine.
  ///
  /// In en, this message translates to:
  /// **'My templates'**
  String get tplMine;

  /// No description provided for @tplSaveCurrent.
  ///
  /// In en, this message translates to:
  /// **'Save current'**
  String get tplSaveCurrent;

  /// No description provided for @tplCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get tplCustomize;

  /// No description provided for @tplLineColor.
  ///
  /// In en, this message translates to:
  /// **'Line color'**
  String get tplLineColor;

  /// No description provided for @tplSpacing.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get tplSpacing;

  /// No description provided for @tplFixedSheet.
  ///
  /// In en, this message translates to:
  /// **'Fixed-size sheet'**
  String get tplFixedSheet;

  /// No description provided for @tplSheetSize.
  ///
  /// In en, this message translates to:
  /// **'Sheet size'**
  String get tplSheetSize;

  /// No description provided for @tplLetter.
  ///
  /// In en, this message translates to:
  /// **'Letter'**
  String get tplLetter;

  /// No description provided for @tplHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How should the template be used?'**
  String get tplHowTitle;

  /// No description provided for @tplHowBody.
  ///
  /// In en, this message translates to:
  /// **'The image will be used as a background to write on.'**
  String get tplHowBody;

  /// No description provided for @tplAsSheet.
  ///
  /// In en, this message translates to:
  /// **'As a fixed sheet'**
  String get tplAsSheet;

  /// No description provided for @tplAsFill.
  ///
  /// In en, this message translates to:
  /// **'Infinite fill'**
  String get tplAsFill;

  /// No description provided for @tplOnlyImage.
  ///
  /// In en, this message translates to:
  /// **'Only templates with an image can be saved'**
  String get tplOnlyImage;

  /// No description provided for @tplSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save template'**
  String get tplSaveTitle;

  /// No description provided for @tplDefaultName.
  ///
  /// In en, this message translates to:
  /// **'My template'**
  String get tplDefaultName;

  /// No description provided for @tplSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get tplSaved;

  /// No description provided for @tplDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get tplDeleteTitle;

  /// No description provided for @tplDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete this saved template?'**
  String get tplDeleteBody;

  /// No description provided for @colorCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get colorCustomTitle;

  /// No description provided for @colorCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get colorCurrent;

  /// No description provided for @colorNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get colorNew;

  /// No description provided for @colorWheel.
  ///
  /// In en, this message translates to:
  /// **'Wheel'**
  String get colorWheel;

  /// No description provided for @colorHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get colorHue;

  /// No description provided for @colorSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get colorSaturation;

  /// No description provided for @colorBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get colorBrightness;

  /// No description provided for @colorUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get colorUse;

  /// No description provided for @timeMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String timeMinAgo(int n);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String timeHoursAgo(int n);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String timeDaysAgo(int n);

  /// No description provided for @timeDeletedNow.
  ///
  /// In en, this message translates to:
  /// **'deleted just now'**
  String get timeDeletedNow;

  /// No description provided for @timeDeletedMin.
  ///
  /// In en, this message translates to:
  /// **'deleted {n} min ago'**
  String timeDeletedMin(int n);

  /// No description provided for @timeDeletedHours.
  ///
  /// In en, this message translates to:
  /// **'deleted {n} h ago'**
  String timeDeletedHours(int n);

  /// No description provided for @timeDeletedDays.
  ///
  /// In en, this message translates to:
  /// **'deleted {n} days ago'**
  String timeDeletedDays(int n);

  /// No description provided for @timeDeletedOn.
  ///
  /// In en, this message translates to:
  /// **'deleted {date}'**
  String timeDeletedOn(String date);

  /// No description provided for @noteDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed from this notebook.'**
  String noteDeleteBody(String title);

  /// No description provided for @noteDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Note {n}'**
  String noteDefaultName(int n);

  /// No description provided for @noteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String noteCount(int count);

  /// No description provided for @notePageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}} · {when}'**
  String notePageCount(int count, String when);

  /// No description provided for @tplImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the image: {error}'**
  String tplImageLoadFailed(String error);

  /// No description provided for @tplSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save error: {error}'**
  String tplSaveFailed(String error);

  /// No description provided for @colorSliders.
  ///
  /// In en, this message translates to:
  /// **'Sliders'**
  String get colorSliders;

  /// No description provided for @selPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get selPaste;

  /// No description provided for @selCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get selCopy;

  /// No description provided for @selCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get selCopied;

  /// No description provided for @selThinner.
  ///
  /// In en, this message translates to:
  /// **'Thinner'**
  String get selThinner;

  /// No description provided for @selThicker.
  ///
  /// In en, this message translates to:
  /// **'Thicker'**
  String get selThicker;

  /// No description provided for @selToText.
  ///
  /// In en, this message translates to:
  /// **'Convert to text'**
  String get selToText;

  /// No description provided for @selDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get selDeselect;

  /// No description provided for @selNoText.
  ///
  /// In en, this message translates to:
  /// **'No text recognized in the selection'**
  String get selNoText;

  /// No description provided for @selConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get selConvert;

  /// No description provided for @popPenType.
  ///
  /// In en, this message translates to:
  /// **'Pen type'**
  String get popPenType;

  /// No description provided for @popThickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get popThickness;

  /// No description provided for @popStraighten.
  ///
  /// In en, this message translates to:
  /// **'Straighten shapes'**
  String get popStraighten;

  /// No description provided for @popNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get popNo;

  /// No description provided for @popOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get popOnHold;

  /// No description provided for @popAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get popAlways;

  /// No description provided for @popShapeOffHint.
  ///
  /// In en, this message translates to:
  /// **'Strokes stay as drawn.'**
  String get popShapeOffHint;

  /// No description provided for @popShapeHoldHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the pen still for almost a second after finishing a line, circle, triangle or rectangle.'**
  String get popShapeHoldHint;

  /// No description provided for @popShapeAlwaysHint.
  ///
  /// In en, this message translates to:
  /// **'Every recognizable shape is straightened when you lift the pen.'**
  String get popShapeAlwaysHint;

  /// No description provided for @popAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced stroke settings'**
  String get popAdvanced;

  /// No description provided for @popMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get popMode;

  /// No description provided for @popPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get popPartial;

  /// No description provided for @popStroke.
  ///
  /// In en, this message translates to:
  /// **'Stroke'**
  String get popStroke;

  /// No description provided for @popHighlighter.
  ///
  /// In en, this message translates to:
  /// **'Highlighter'**
  String get popHighlighter;

  /// No description provided for @popEraseOff.
  ///
  /// In en, this message translates to:
  /// **'Erases only what you touch, like a rubber.'**
  String get popEraseOff;

  /// No description provided for @popEraseStroke.
  ///
  /// In en, this message translates to:
  /// **'Erases the whole stroke when touched.'**
  String get popEraseStroke;

  /// No description provided for @popEraseHighlighter.
  ///
  /// In en, this message translates to:
  /// **'Only erases highlighter; ink is untouched.'**
  String get popEraseHighlighter;

  /// No description provided for @popSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get popSize;

  /// No description provided for @tbBackToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to library'**
  String get tbBackToLibrary;

  /// No description provided for @tbHidePages.
  ///
  /// In en, this message translates to:
  /// **'Hide pages'**
  String get tbHidePages;

  /// No description provided for @tbPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get tbPages;

  /// No description provided for @tbHideLayers.
  ///
  /// In en, this message translates to:
  /// **'Hide layers'**
  String get tbHideLayers;

  /// No description provided for @tbShowTools.
  ///
  /// In en, this message translates to:
  /// **'Show drawing tools'**
  String get tbShowTools;

  /// No description provided for @tbHideTools.
  ///
  /// In en, this message translates to:
  /// **'Hide drawing tools'**
  String get tbHideTools;

  /// No description provided for @tbLayers.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get tbLayers;

  /// No description provided for @tbInsertImage.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get tbInsertImage;

  /// No description provided for @tbRuler.
  ///
  /// In en, this message translates to:
  /// **'Ruler'**
  String get tbRuler;

  /// No description provided for @tbRulerNext.
  ///
  /// In en, this message translates to:
  /// **'Ruler (tap: protractor)'**
  String get tbRulerNext;

  /// No description provided for @tbProtractorNext.
  ///
  /// In en, this message translates to:
  /// **'Protractor (tap: hide)'**
  String get tbProtractorNext;

  /// No description provided for @tbMoveSelect.
  ///
  /// In en, this message translates to:
  /// **'Move / select images and strokes'**
  String get tbMoveSelect;

  /// No description provided for @tbFill.
  ///
  /// In en, this message translates to:
  /// **'Fill area'**
  String get tbFill;

  /// No description provided for @tbHideMagnifier.
  ///
  /// In en, this message translates to:
  /// **'Close zoom writing'**
  String get tbHideMagnifier;

  /// No description provided for @tbMagnifier.
  ///
  /// In en, this message translates to:
  /// **'Zoom writing'**
  String get tbMagnifier;

  /// No description provided for @tbLaserOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off laser pointer'**
  String get tbLaserOff;

  /// No description provided for @tbLaser.
  ///
  /// In en, this message translates to:
  /// **'Laser pointer'**
  String get tbLaser;

  /// No description provided for @tbInsertSticker.
  ///
  /// In en, this message translates to:
  /// **'Insert sticker'**
  String get tbInsertSticker;

  /// No description provided for @tbPageTemplate.
  ///
  /// In en, this message translates to:
  /// **'Page template'**
  String get tbPageTemplate;

  /// No description provided for @tbMoreTools.
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get tbMoreTools;

  /// No description provided for @tbUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get tbUndo;

  /// No description provided for @tbRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get tbRedo;

  /// No description provided for @pgUnbookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get pgUnbookmark;

  /// No description provided for @pgBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark page'**
  String get pgBookmark;

  /// No description provided for @pgShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get pgShowAll;

  /// No description provided for @pgOnlyBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked only'**
  String get pgOnlyBookmarked;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @pgOptions.
  ///
  /// In en, this message translates to:
  /// **'Page options'**
  String get pgOptions;

  /// No description provided for @pgNew.
  ///
  /// In en, this message translates to:
  /// **'New page'**
  String get pgNew;

  /// No description provided for @tagTitle.
  ///
  /// In en, this message translates to:
  /// **'Notebook tags'**
  String get tagTitle;

  /// No description provided for @tagSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To find it and group it in smart folders'**
  String get tagSubtitle;

  /// No description provided for @tagActive.
  ///
  /// In en, this message translates to:
  /// **'Active tags'**
  String get tagActive;

  /// No description provided for @tagOthers.
  ///
  /// In en, this message translates to:
  /// **'Other tags'**
  String get tagOthers;

  /// No description provided for @tagNew.
  ///
  /// In en, this message translates to:
  /// **'New tag…'**
  String get tagNew;

  /// No description provided for @tagAdd.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get tagAdd;

  /// No description provided for @tagSave.
  ///
  /// In en, this message translates to:
  /// **'Save tags'**
  String get tagSave;

  /// No description provided for @trashDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get trashDeleteForever;

  /// No description provided for @trashEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty trash'**
  String get trashEmptyTitle;

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get trashEmpty;

  /// No description provided for @trashSubtitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Anything you delete stays here for 30 days'**
  String get trashSubtitleEmpty;

  /// No description provided for @trashEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashEmptyState;

  /// No description provided for @trashLegacy.
  ///
  /// In en, this message translates to:
  /// **'Notebook (old format)'**
  String get trashLegacy;

  /// No description provided for @trashNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get trashNote;

  /// No description provided for @trashReturn.
  ///
  /// In en, this message translates to:
  /// **'Return to its notebook'**
  String get trashReturn;

  /// No description provided for @strokeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pressure, smoothing and stroke fluidity'**
  String get strokeSubtitle;

  /// No description provided for @strokeNone.
  ///
  /// In en, this message translates to:
  /// **'The eraser and selection have no stroke options.'**
  String get strokeNone;

  /// No description provided for @strokeQuickSize.
  ///
  /// In en, this message translates to:
  /// **'Quick size'**
  String get strokeQuickSize;

  /// No description provided for @strokePressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure variation'**
  String get strokePressure;

  /// No description provided for @strokePressureDesc.
  ///
  /// In en, this message translates to:
  /// **'How much thickness changes when you press'**
  String get strokePressureDesc;

  /// No description provided for @strokeSmoothing.
  ///
  /// In en, this message translates to:
  /// **'Smoothing'**
  String get strokeSmoothing;

  /// No description provided for @strokeSmoothingDesc.
  ///
  /// In en, this message translates to:
  /// **'Rounds the stroke\'s curves'**
  String get strokeSmoothingDesc;

  /// No description provided for @strokeStabilizer.
  ///
  /// In en, this message translates to:
  /// **'Stabilizer'**
  String get strokeStabilizer;

  /// No description provided for @strokeStabilizerDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduces hand tremor'**
  String get strokeStabilizerDesc;

  /// No description provided for @sizeThin.
  ///
  /// In en, this message translates to:
  /// **'Thin'**
  String get sizeThin;

  /// No description provided for @sizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sizeMedium;

  /// No description provided for @sizeThick.
  ///
  /// In en, this message translates to:
  /// **'Thick'**
  String get sizeThick;

  /// No description provided for @sizeExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get sizeExtra;

  /// No description provided for @sizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get sizeSmall;

  /// No description provided for @sizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get sizeLarge;

  /// No description provided for @toolPen.
  ///
  /// In en, this message translates to:
  /// **'Ballpoint pen'**
  String get toolPen;

  /// No description provided for @toolPencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get toolPencil;

  /// No description provided for @toolCalligraphy.
  ///
  /// In en, this message translates to:
  /// **'Calligraphy pen'**
  String get toolCalligraphy;

  /// No description provided for @toolBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get toolBrush;

  /// No description provided for @toolMarker.
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get toolMarker;

  /// No description provided for @toolSpray.
  ///
  /// In en, this message translates to:
  /// **'Spray'**
  String get toolSpray;

  /// No description provided for @toolEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get toolEraser;

  /// No description provided for @toolSelect.
  ///
  /// In en, this message translates to:
  /// **'Move / select'**
  String get toolSelect;

  /// No description provided for @toolLasso.
  ///
  /// In en, this message translates to:
  /// **'Lasso'**
  String get toolLasso;

  /// No description provided for @toolFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get toolFill;

  /// No description provided for @toolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get toolText;

  /// No description provided for @selRecognizeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize: {error}'**
  String selRecognizeFailed(String error);

  /// No description provided for @tbPenSlot.
  ///
  /// In en, this message translates to:
  /// **'{tool} {n}'**
  String tbPenSlot(String tool, int n);

  /// No description provided for @tbPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {n} of {total}'**
  String tbPageOf(int n, int total);

  /// No description provided for @pgPagesCount.
  ///
  /// In en, this message translates to:
  /// **'Pages ({n})'**
  String pgPagesCount(int n);

  /// No description provided for @strokeOptionsOf.
  ///
  /// In en, this message translates to:
  /// **'{tool} options'**
  String strokeOptionsOf(String tool);

  /// No description provided for @trashRestoredMsg.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" restored'**
  String trashRestoredMsg(String title);

  /// No description provided for @trashPurgeBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be permanently deleted. This cannot be undone.'**
  String trashPurgeBody(String title);

  /// No description provided for @trashEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}} will be permanently deleted. This cannot be undone.'**
  String trashEmptyBody(int count);

  /// No description provided for @trashSubtitleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}} · deleted automatically after 30 days'**
  String trashSubtitleCount(int count);

  /// No description provided for @trashEmptyStateBody.
  ///
  /// In en, this message translates to:
  /// **'Notebooks and notes you delete are kept here for 30 days before being permanently removed.'**
  String get trashEmptyStateBody;

  /// No description provided for @trashNotebookKind.
  ///
  /// In en, this message translates to:
  /// **'Notebook · {count, plural, =1{1 note} other{{count} notes}}'**
  String trashNotebookKind(int count);

  /// No description provided for @trashNoteOf.
  ///
  /// In en, this message translates to:
  /// **'Note from “{title}”'**
  String trashNoteOf(String title);

  /// No description provided for @trashLeftTomorrow.
  ///
  /// In en, this message translates to:
  /// **'deleted tomorrow'**
  String get trashLeftTomorrow;

  /// No description provided for @trashLeftDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days left'**
  String trashLeftDays(int n);

  /// No description provided for @trashInfoLine.
  ///
  /// In en, this message translates to:
  /// **'{what} · {deleted} · {left}'**
  String trashInfoLine(String what, String deleted, String left);

  /// No description provided for @edLayerLocked.
  ///
  /// In en, this message translates to:
  /// **'Layer locked — unlock it to edit'**
  String get edLayerLocked;

  /// No description provided for @expTitle.
  ///
  /// In en, this message translates to:
  /// **'Export options'**
  String get expTitle;

  /// No description provided for @expLow.
  ///
  /// In en, this message translates to:
  /// **'Low (1024 px)'**
  String get expLow;

  /// No description provided for @expMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (2048 px)'**
  String get expMedium;

  /// No description provided for @expHigh.
  ///
  /// In en, this message translates to:
  /// **'High (4096 px)'**
  String get expHigh;

  /// No description provided for @expMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum (8192 px)'**
  String get expMax;

  /// No description provided for @expTransparent.
  ///
  /// In en, this message translates to:
  /// **'Transparent background'**
  String get expTransparent;

  /// No description provided for @expTransparentHint.
  ///
  /// In en, this message translates to:
  /// **'No template or paper'**
  String get expTransparentHint;

  /// No description provided for @expStrokesOnly.
  ///
  /// In en, this message translates to:
  /// **'Strokes only'**
  String get expStrokesOnly;

  /// No description provided for @expStrokesOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'No images or template'**
  String get expStrokesOnlyHint;

  /// No description provided for @expExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get expExport;

  /// No description provided for @ocrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'OCR is only available on Android and iOS'**
  String get ocrUnsupported;

  /// No description provided for @ocrWorking.
  ///
  /// In en, this message translates to:
  /// **'Recognizing text…'**
  String get ocrWorking;

  /// No description provided for @ocrNoText.
  ///
  /// In en, this message translates to:
  /// **'No text recognized on this page'**
  String get ocrNoText;

  /// No description provided for @ocrResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Recognized text'**
  String get ocrResultTitle;

  /// No description provided for @ocrCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied to the clipboard'**
  String get ocrCopied;

  /// No description provided for @ocrEditResult.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get ocrEditResult;

  /// No description provided for @ocrTapLineToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap a line to recognize it again'**
  String get ocrTapLineToRetry;

  /// No description provided for @ocrRetryLine.
  ///
  /// In en, this message translates to:
  /// **'Recognize this line again'**
  String get ocrRetryLine;

  /// No description provided for @ocrLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Recognition language'**
  String get ocrLanguageTitle;

  /// No description provided for @ocrLanguageDownload.
  ///
  /// In en, this message translates to:
  /// **'Download (~20 MB)'**
  String get ocrLanguageDownload;

  /// No description provided for @ocrLanguageDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download the {language} model?'**
  String ocrLanguageDownloadTitle(Object language);

  /// No description provided for @ocrLanguageDownloadMessage.
  ///
  /// In en, this message translates to:
  /// **'About 20 MB will be downloaded from Google over Wi-Fi. It works offline afterwards.'**
  String get ocrLanguageDownloadMessage;

  /// No description provided for @ocrLanguageDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the {language} model. Connect to Wi-Fi and try again.'**
  String ocrLanguageDownloadFailed(Object language);

  /// No description provided for @edGoogleAccount.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get edGoogleAccount;

  /// No description provided for @edSyncedCloud.
  ///
  /// In en, this message translates to:
  /// **'Synced with the cloud'**
  String get edSyncedCloud;

  /// No description provided for @edRestoreCloud.
  ///
  /// In en, this message translates to:
  /// **'Restore from the cloud'**
  String get edRestoreCloud;

  /// No description provided for @edRestoreCloudHint.
  ///
  /// In en, this message translates to:
  /// **'Latest version (last-write-wins)'**
  String get edRestoreCloudHint;

  /// No description provided for @edDriveVersions.
  ///
  /// In en, this message translates to:
  /// **'View versions in Drive'**
  String get edDriveVersions;

  /// No description provided for @edUploadNot3.
  ///
  /// In en, this message translates to:
  /// **'Upload .inklus file'**
  String get edUploadNot3;

  /// No description provided for @edSyncOnForNotebook.
  ///
  /// In en, this message translates to:
  /// **'Sync: on for this notebook'**
  String get edSyncOnForNotebook;

  /// No description provided for @edSyncOffForNotebook.
  ///
  /// In en, this message translates to:
  /// **'Sync: off for this notebook'**
  String get edSyncOffForNotebook;

  /// No description provided for @edSyncDisabledMsg.
  ///
  /// In en, this message translates to:
  /// **'Sync turned off for this notebook'**
  String get edSyncDisabledMsg;

  /// No description provided for @edSyncEnabledMsg.
  ///
  /// In en, this message translates to:
  /// **'Sync turned on for this notebook'**
  String get edSyncEnabledMsg;

  /// No description provided for @edNoteSynced.
  ///
  /// In en, this message translates to:
  /// **'Note synced with Google Drive'**
  String get edNoteSynced;

  /// No description provided for @edPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password (leave empty if not encrypted)'**
  String get edPasswordHint;

  /// No description provided for @edNoCloudCopy.
  ///
  /// In en, this message translates to:
  /// **'There is no copy of this note in Google Drive yet'**
  String get edNoCloudCopy;

  /// No description provided for @edNoteRestored.
  ///
  /// In en, this message translates to:
  /// **'Note restored from Google Drive'**
  String get edNoteRestored;

  /// No description provided for @edIsFullBackup.
  ///
  /// In en, this message translates to:
  /// **'That file is a full backup, not a .inklus notebook'**
  String get edIsFullBackup;

  /// No description provided for @edNoPassword.
  ///
  /// In en, this message translates to:
  /// **'No password'**
  String get edNoPassword;

  /// No description provided for @edNotebookTitle.
  ///
  /// In en, this message translates to:
  /// **'Notebook title'**
  String get edNotebookTitle;

  /// No description provided for @pdfUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Importing PDFs is only available on Android/iOS for now'**
  String get pdfUnsupported;

  /// No description provided for @pdfReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the PDF'**
  String get pdfReadFailed;

  /// No description provided for @verRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore version'**
  String get verRestoreTitle;

  /// No description provided for @verRestored.
  ///
  /// In en, this message translates to:
  /// **'Version restored'**
  String get verRestored;

  /// No description provided for @verEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted copy'**
  String get verEncrypted;

  /// No description provided for @verPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get verPasswordHint;

  /// No description provided for @verDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Decrypt'**
  String get verDecrypt;

  /// No description provided for @inkUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Handwriting recognition is only available on Android and iOS'**
  String get inkUnsupported;

  /// No description provided for @edDeleteImage.
  ///
  /// In en, this message translates to:
  /// **'Delete image'**
  String get edDeleteImage;

  /// No description provided for @edExitPresent.
  ///
  /// In en, this message translates to:
  /// **'Exit presentation'**
  String get edExitPresent;

  /// No description provided for @edLaserOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off laser'**
  String get edLaserOff;

  /// No description provided for @edGoToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get edGoToPage;

  /// No description provided for @edGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get edGo;

  /// No description provided for @edNoStickers.
  ///
  /// In en, this message translates to:
  /// **'You have no stickers installed yet.'**
  String get edNoStickers;

  /// No description provided for @edOpenMarket.
  ///
  /// In en, this message translates to:
  /// **'Open the marketplace'**
  String get edOpenMarket;

  /// No description provided for @edSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get edSyncing;

  /// No description provided for @edSyncToDrive.
  ///
  /// In en, this message translates to:
  /// **'Sync with Google Drive'**
  String get edSyncToDrive;

  /// No description provided for @edSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get edSynced;

  /// No description provided for @edSyncError.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get edSyncError;

  /// No description provided for @menuPagePng.
  ///
  /// In en, this message translates to:
  /// **'Page as image (PNG)'**
  String get menuPagePng;

  /// No description provided for @menuPagePdf.
  ///
  /// In en, this message translates to:
  /// **'Page as PDF'**
  String get menuPagePdf;

  /// No description provided for @menuNotePdf.
  ///
  /// In en, this message translates to:
  /// **'Whole note (PDF)'**
  String get menuNotePdf;

  /// No description provided for @menuStrokesSvg.
  ///
  /// In en, this message translates to:
  /// **'Strokes (SVG)'**
  String get menuStrokesSvg;

  /// No description provided for @menuPptx.
  ///
  /// In en, this message translates to:
  /// **'Presentation (PowerPoint)'**
  String get menuPptx;

  /// No description provided for @menuNot3Copy.
  ///
  /// In en, this message translates to:
  /// **'Copy as .inklus'**
  String get menuNot3Copy;

  /// No description provided for @menuShareImage.
  ///
  /// In en, this message translates to:
  /// **'Share image'**
  String get menuShareImage;

  /// No description provided for @menuSharePdf.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get menuSharePdf;

  /// No description provided for @menuShareNot3.
  ///
  /// In en, this message translates to:
  /// **'Share .inklus'**
  String get menuShareNot3;

  /// No description provided for @menuExportShare.
  ///
  /// In en, this message translates to:
  /// **'Export and share'**
  String get menuExportShare;

  /// No description provided for @menuTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template…'**
  String get menuTemplate;

  /// No description provided for @menuGoToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page…'**
  String get menuGoToPage;

  /// No description provided for @menuImportPdf.
  ///
  /// In en, this message translates to:
  /// **'Import PDF to annotate'**
  String get menuImportPdf;

  /// No description provided for @menuClearPage.
  ///
  /// In en, this message translates to:
  /// **'Clear page'**
  String get menuClearPage;

  /// No description provided for @menuPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get menuPage;

  /// No description provided for @menuSearchNote.
  ///
  /// In en, this message translates to:
  /// **'Search in note'**
  String get menuSearchNote;

  /// No description provided for @menuIndexInk.
  ///
  /// In en, this message translates to:
  /// **'Index handwriting (to search it)'**
  String get menuIndexInk;

  /// No description provided for @menuIndexInkUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Index handwriting (Android/iOS only)'**
  String get menuIndexInkUnsupported;

  /// No description provided for @menuOcr.
  ///
  /// In en, this message translates to:
  /// **'Recognize text (OCR)'**
  String get menuOcr;

  /// No description provided for @menuOcrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'OCR (Android/iOS only)'**
  String get menuOcrUnsupported;

  /// No description provided for @menuVersions.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get menuVersions;

  /// No description provided for @menuReminder.
  ///
  /// In en, this message translates to:
  /// **'Create reminder'**
  String get menuReminder;

  /// No description provided for @menuNightOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off night mode'**
  String get menuNightOff;

  /// No description provided for @menuNightOn.
  ///
  /// In en, this message translates to:
  /// **'Writing night mode'**
  String get menuNightOn;

  /// No description provided for @menuPresent.
  ///
  /// In en, this message translates to:
  /// **'Presentation mode'**
  String get menuPresent;

  /// No description provided for @menuHapticsOn.
  ///
  /// In en, this message translates to:
  /// **'Writing vibration: on'**
  String get menuHapticsOn;

  /// No description provided for @menuHapticsOff.
  ///
  /// In en, this message translates to:
  /// **'Writing vibration: off'**
  String get menuHapticsOff;

  /// No description provided for @menuContinuousScroll.
  ///
  /// In en, this message translates to:
  /// **'Continuous scroll between sheets'**
  String get menuContinuousScroll;

  /// No description provided for @menuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// No description provided for @menuBackup.
  ///
  /// In en, this message translates to:
  /// **'Export full backup'**
  String get menuBackup;

  /// No description provided for @menuRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Import .inklus or backup'**
  String get menuRestoreBackup;

  /// No description provided for @menuData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get menuData;

  /// No description provided for @menuStats.
  ///
  /// In en, this message translates to:
  /// **'Writing statistics'**
  String get menuStats;

  /// No description provided for @clearPageBody.
  ///
  /// In en, this message translates to:
  /// **'All the page\'s content will be erased. You can undo it afterwards.'**
  String get clearPageBody;

  /// No description provided for @clearPageAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearPageAction;

  /// No description provided for @pgPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get pgPrev;

  /// No description provided for @pgNext.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get pgNext;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @zoomFit.
  ///
  /// In en, this message translates to:
  /// **'Fit to view'**
  String get zoomFit;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @shareTextPage.
  ///
  /// In en, this message translates to:
  /// **'Not3 page'**
  String get shareTextPage;

  /// No description provided for @shareTextNotebook.
  ///
  /// In en, this message translates to:
  /// **'Not3 notebook'**
  String get shareTextNotebook;

  /// No description provided for @edInsertImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not insert the image: {error}'**
  String edInsertImageFailed(String error);

  /// No description provided for @expSvgFailed.
  ///
  /// In en, this message translates to:
  /// **'SVG export error: {error}'**
  String expSvgFailed(String error);

  /// No description provided for @ocrFailed.
  ///
  /// In en, this message translates to:
  /// **'Text recognition error: {error}'**
  String ocrFailed(String error);

  /// No description provided for @expFailed.
  ///
  /// In en, this message translates to:
  /// **'Export error: {error}'**
  String expFailed(String error);

  /// No description provided for @expPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview: {name}'**
  String expPreview(String name);

  /// No description provided for @expSaveDialog.
  ///
  /// In en, this message translates to:
  /// **'Save {name}'**
  String expSaveDialog(String name);

  /// No description provided for @expDone.
  ///
  /// In en, this message translates to:
  /// **'Exported: {path}'**
  String expDone(String path);

  /// No description provided for @expSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file: {error}'**
  String expSaveFailed(String error);

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share error: {error}'**
  String shareFailed(String error);

  /// No description provided for @edSignInIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not complete. Detail: {detail}'**
  String edSignInIncomplete(String detail);

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload error: {error}'**
  String uploadFailed(String error);

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore error: {error}'**
  String restoreFailed(String error);

  /// No description provided for @edFileUploaded.
  ///
  /// In en, this message translates to:
  /// **'File \"{name}\" uploaded to Google Drive'**
  String edFileUploaded(String name);

  /// No description provided for @pdfImported.
  ///
  /// In en, this message translates to:
  /// **'PDF imported: {count, plural, =1{1 page} other{{count} pages}} to annotate'**
  String pdfImported(int count);

  /// No description provided for @pdfImportFailed.
  ///
  /// In en, this message translates to:
  /// **'PDF import error: {error}'**
  String pdfImportFailed(String error);

  /// No description provided for @verRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'The note will go back to how it was on {date}.\\n\\nThe current state is saved first as a local version, so you can undo the restore from this same history.'**
  String verRestoreBody(String date);

  /// No description provided for @verRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the version: {error}'**
  String verRestoreFailed(String error);

  /// No description provided for @pptxFailed.
  ///
  /// In en, this message translates to:
  /// **'PowerPoint export error: {error}'**
  String pptxFailed(String error);

  /// No description provided for @reminderCreated.
  ///
  /// In en, this message translates to:
  /// **'Reminder created for {date} at {time}'**
  String reminderCreated(String date, String time);

  /// No description provided for @inkIndexed.
  ///
  /// In en, this message translates to:
  /// **'Handwriting indexed on {count, plural, =1{1 page} other{{count} pages}}: you can now search it'**
  String inkIndexed(int count);

  /// No description provided for @inkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize the handwriting: {error}'**
  String inkFailed(String error);

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup export error: {error}'**
  String backupFailed(String error);

  /// No description provided for @importDoneOpen.
  ///
  /// In en, this message translates to:
  /// **'{message}. Open it from the library.'**
  String importDoneOpen(String message);

  /// No description provided for @noteHasPages.
  ///
  /// In en, this message translates to:
  /// **'The note has {count, plural, =1{1 page} other{{count} pages}}'**
  String noteHasPages(int count);

  /// No description provided for @stickerInsertFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not insert the sticker: {error}'**
  String stickerInsertFailed(String error);

  /// No description provided for @remNoNotebooks.
  ///
  /// In en, this message translates to:
  /// **'No notebooks to link'**
  String get remNoNotebooks;

  /// No description provided for @remPickNotebook.
  ///
  /// In en, this message translates to:
  /// **'Select notebook'**
  String get remPickNotebook;

  /// No description provided for @remPickHint.
  ///
  /// In en, this message translates to:
  /// **'The reminder will open this notebook'**
  String get remPickHint;

  /// No description provided for @remCreated.
  ///
  /// In en, this message translates to:
  /// **'Reminder created'**
  String get remCreated;

  /// No description provided for @remMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder message'**
  String get remMessageTitle;

  /// No description provided for @remMessageHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Review class notes'**
  String get remMessageHint;

  /// No description provided for @remNoMessage.
  ///
  /// In en, this message translates to:
  /// **'No message'**
  String get remNoMessage;

  /// No description provided for @remTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remTitle;

  /// No description provided for @remSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts linked to your notebooks'**
  String get remSubtitle;

  /// No description provided for @remEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reminders'**
  String get remEmptyTitle;

  /// No description provided for @remPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get remPending;

  /// No description provided for @remDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get remDone;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your writing activity on this device'**
  String get statsSubtitle;

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get statsEmptyTitle;

  /// No description provided for @statsStrokes.
  ///
  /// In en, this message translates to:
  /// **'Strokes'**
  String get statsStrokes;

  /// No description provided for @statsMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get statsMinutes;

  /// No description provided for @statsActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get statsActiveDays;

  /// No description provided for @statsStreaks.
  ///
  /// In en, this message translates to:
  /// **'Streaks'**
  String get statsStreaks;

  /// No description provided for @statsCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get statsCurrentStreak;

  /// No description provided for @statsRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get statsRecord;

  /// No description provided for @statsActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity — last 30 days'**
  String get statsActivity;

  /// No description provided for @statsDaysWithPages.
  ///
  /// In en, this message translates to:
  /// **'Days with new pages'**
  String get statsDaysWithPages;

  /// No description provided for @smartTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart folders'**
  String get smartTitle;

  /// No description provided for @smartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize your notebooks automatically'**
  String get smartSubtitle;

  /// No description provided for @smartByColor.
  ///
  /// In en, this message translates to:
  /// **'By color'**
  String get smartByColor;

  /// No description provided for @smartByTag.
  ///
  /// In en, this message translates to:
  /// **'By tag'**
  String get smartByTag;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onbStart;

  /// No description provided for @onb1Title.
  ///
  /// In en, this message translates to:
  /// **'Write with your pen'**
  String get onb1Title;

  /// No description provided for @onb2Title.
  ///
  /// In en, this message translates to:
  /// **'Move with your fingers'**
  String get onb2Title;

  /// No description provided for @onb3Title.
  ///
  /// In en, this message translates to:
  /// **'Tools on top'**
  String get onb3Title;

  /// No description provided for @onb4Title.
  ///
  /// In en, this message translates to:
  /// **'Your notes are yours'**
  String get onb4Title;

  /// No description provided for @layerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add layer'**
  String get layerAdd;

  /// No description provided for @layerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename layer'**
  String get layerRename;

  /// No description provided for @verSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When restoring, the current state is saved first'**
  String get verSubtitle;

  /// No description provided for @verOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get verOnDevice;

  /// No description provided for @verNoLocal.
  ///
  /// In en, this message translates to:
  /// **'There are no local copies of this note yet.'**
  String get verNoLocal;

  /// No description provided for @verOnDrive.
  ///
  /// In en, this message translates to:
  /// **'On Google Drive'**
  String get verOnDrive;

  /// No description provided for @verNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'This note has not been uploaded to Drive yet.'**
  String get verNotUploaded;

  /// No description provided for @smartThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get smartThisWeek;

  /// No description provided for @smartNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags'**
  String get smartNoTags;

  /// No description provided for @smartOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get smartOther;

  /// No description provided for @colorNone.
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get colorNone;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// No description provided for @colorTurquoise.
  ///
  /// In en, this message translates to:
  /// **'Turquoise'**
  String get colorTurquoise;

  /// No description provided for @colorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// No description provided for @onb1Body.
  ///
  /// In en, this message translates to:
  /// **'Rest your hand without worry: Not3 recognizes the pen and ignores your palm. The pen\'s eraser end or side button erases.'**
  String get onb1Body;

  /// No description provided for @onb2Body.
  ///
  /// In en, this message translates to:
  /// **'With the pen, one finger scrolls the page and two fingers zoom. You can go back to drawing with your finger from the toolbar.'**
  String get onb2Body;

  /// No description provided for @onb3Body.
  ///
  /// In en, this message translates to:
  /// **'Tap a tool to use it and tap it again to see its options: thickness, color, partial eraser, shapes…'**
  String get onb3Body;

  /// No description provided for @onb4Body.
  ///
  /// In en, this message translates to:
  /// **'Everything is saved on this device, with no accounts or ads. If you want, you can back up to your Google Drive.'**
  String get onb4Body;

  /// No description provided for @remEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create reminders linked to your notebooks so you never forget anything.'**
  String get remEmptyBody;

  /// No description provided for @statsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start writing in your notebooks and your statistics will appear here.'**
  String get statsEmptyBody;

  /// No description provided for @remOverdue.
  ///
  /// In en, this message translates to:
  /// **' · overdue'**
  String get remOverdue;

  /// No description provided for @statsDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String statsDays(int count);

  /// No description provided for @statsDayTooltip.
  ///
  /// In en, this message translates to:
  /// **'{date}: {strokes} strokes, {pages} pages'**
  String statsDayTooltip(String date, int strokes, int pages);

  /// No description provided for @searchInNote.
  ///
  /// In en, this message translates to:
  /// **'Search in this note'**
  String get searchInNote;

  /// No description provided for @searchInAll.
  ///
  /// In en, this message translates to:
  /// **'Search in all notes'**
  String get searchInAll;

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type to search'**
  String get searchPrompt;

  /// No description provided for @searchMatches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match} other{{count} matches}}'**
  String searchMatches(int count);

  /// No description provided for @searchInfo.
  ///
  /// In en, this message translates to:
  /// **'Includes text boxes and handwriting that has already been recognized (Note menu → Index handwriting).'**
  String get searchInfo;

  /// No description provided for @searchTitleMatch.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get searchTitleMatch;

  /// No description provided for @pgDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate page'**
  String get pgDuplicate;

  /// No description provided for @pgDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get pgDelete;

  /// No description provided for @verDriveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not query Drive: {error}'**
  String verDriveFailed(String error);

  /// No description provided for @colorSemantics.
  ///
  /// In en, this message translates to:
  /// **'Color #{hex}'**
  String colorSemantics(String hex);

  /// No description provided for @errNotNot3.
  ///
  /// In en, this message translates to:
  /// **'The file is not an .inklus notebook or an Not3 backup.'**
  String get errNotNot3;

  /// No description provided for @errNotNot3File.
  ///
  /// In en, this message translates to:
  /// **'Not a valid .inklus notebook'**
  String get errNotNot3File;

  /// No description provided for @errNotNot3V2.
  ///
  /// In en, this message translates to:
  /// **'Not a valid .inklus v2 notebook'**
  String get errNotNot3V2;

  /// No description provided for @errCatalogTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Catalog is too large'**
  String get errCatalogTooLarge;

  /// No description provided for @errCatalogVersion.
  ///
  /// In en, this message translates to:
  /// **'Unsupported catalog version: {version}'**
  String errCatalogVersion(String version);

  /// No description provided for @errOcrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'OCR is only available on Android and iOS.'**
  String get errOcrUnsupported;

  /// No description provided for @errNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google first.'**
  String get errNotSignedIn;

  /// No description provided for @errEncrypted.
  ///
  /// In en, this message translates to:
  /// **'The copy is encrypted: a password is required'**
  String get errEncrypted;

  /// No description provided for @driveConfigBody.
  ///
  /// In en, this message translates to:
  /// **'Google configuration error (clientConfigurationError).\\n\\nLikely cause: this app\'s signing SHA-1 is not registered in Google Cloud Console for the package io.github.pyrhomits.not3.\\n\\nFix:\\n1. Go to Google Cloud Console → APIs & Services → Credentials\\n2. Create or edit the Android OAuth client ID with package io.github.pyrhomits.not3 and your signing SHA-1\\n3. Enable Google Sign-In on the consent screen\\n\\nOriginal error: {details}'**
  String driveConfigBody(String details);

  /// No description provided for @noticeStylus.
  ///
  /// In en, this message translates to:
  /// **'Pen detected: your finger now scrolls the page (turn it on in the toolbar if you want to draw with your finger)'**
  String get noticeStylus;

  /// No description provided for @noticePageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Page deleted'**
  String get noticePageDeleted;

  /// No description provided for @noticeFileUploaded.
  ///
  /// In en, this message translates to:
  /// **'File uploaded to Google Drive'**
  String get noticeFileUploaded;

  /// No description provided for @importBackupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored: {count, plural, =1{1 notebook} other{{count} notebooks}}'**
  String importBackupRestored(int count);

  /// No description provided for @importNotebookDone.
  ///
  /// In en, this message translates to:
  /// **'Notebook \"{title}\" imported ({count, plural, =1{1 note} other{{count} notes}})'**
  String importNotebookDone(String title, int count);

  /// No description provided for @importNotebookSimple.
  ///
  /// In en, this message translates to:
  /// **'Notebook \"{title}\" imported'**
  String importNotebookSimple(String title);

  /// No description provided for @driveRestoreNone.
  ///
  /// In en, this message translates to:
  /// **'There are no Not3 copies in your Google Drive'**
  String get driveRestoreNone;

  /// No description provided for @driveRestoreUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Everything is up to date: nothing to restore'**
  String get driveRestoreUpToDate;

  /// No description provided for @driveRestoreUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note updated} other{{count} notes updated}}'**
  String driveRestoreUpdated(int count);

  /// No description provided for @driveRestoreAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recovered} other{{count} recovered}}'**
  String driveRestoreAdded(int count);

  /// No description provided for @driveRecovered.
  ///
  /// In en, this message translates to:
  /// **'Recovered from Drive'**
  String get driveRecovered;

  /// No description provided for @packClassicName.
  ///
  /// In en, this message translates to:
  /// **'Classic notebooks'**
  String get packClassicName;

  /// No description provided for @packClassicDesc.
  ///
  /// In en, this message translates to:
  /// **'Wide and narrow ruling, 5 mm grid, dots and staff.'**
  String get packClassicDesc;

  /// No description provided for @packTechName.
  ///
  /// In en, this message translates to:
  /// **'Technical paper'**
  String get packTechName;

  /// No description provided for @packTechDesc.
  ///
  /// In en, this message translates to:
  /// **'Fine graph-paper grid and column planner, in soft tones.'**
  String get packTechDesc;

  /// No description provided for @packStudyName.
  ///
  /// In en, this message translates to:
  /// **'Study palette'**
  String get packStudyName;

  /// No description provided for @packStudyDesc.
  ///
  /// In en, this message translates to:
  /// **'Blue and black ink, correction red, green and orange for emphasis.'**
  String get packStudyDesc;

  /// No description provided for @packPastelName.
  ///
  /// In en, this message translates to:
  /// **'Pastel palette'**
  String get packPastelName;

  /// No description provided for @packPastelDesc.
  ///
  /// In en, this message translates to:
  /// **'Soft tones for pretty notes and diagrams.'**
  String get packPastelDesc;

  /// No description provided for @packEarthName.
  ///
  /// In en, this message translates to:
  /// **'Earth palette'**
  String get packEarthName;

  /// No description provided for @packEarthDesc.
  ///
  /// In en, this message translates to:
  /// **'Ochres, olive and terracotta, with good contrast on paper.'**
  String get packEarthDesc;

  /// No description provided for @coverSimple.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get coverSimple;

  /// No description provided for @coverClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get coverClassic;

  /// No description provided for @coverAurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get coverAurora;

  /// No description provided for @coverWaves.
  ///
  /// In en, this message translates to:
  /// **'Waves'**
  String get coverWaves;

  /// No description provided for @coverGeometric.
  ///
  /// In en, this message translates to:
  /// **'Geometric'**
  String get coverGeometric;

  /// No description provided for @coverSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get coverSun;

  /// No description provided for @coverDots.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get coverDots;

  /// No description provided for @coverLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get coverLines;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @defaultNotebookTitle.
  ///
  /// In en, this message translates to:
  /// **'My notebook'**
  String get defaultNotebookTitle;

  /// No description provided for @createFromFile.
  ///
  /// In en, this message translates to:
  /// **'Or start from a file'**
  String get createFromFile;

  /// No description provided for @createFromFileHint.
  ///
  /// In en, this message translates to:
  /// **'Upload a PDF or photos and write on top of each page.'**
  String get createFromFileHint;

  /// No description provided for @createFromPdf.
  ///
  /// In en, this message translates to:
  /// **'From a PDF'**
  String get createFromPdf;

  /// No description provided for @createFromImages.
  ///
  /// In en, this message translates to:
  /// **'From images'**
  String get createFromImages;

  /// No description provided for @createFromFileRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get createFromFileRemove;

  /// No description provided for @createFromFilePages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String createFromFilePages(int count);

  /// No description provided for @menuTwoFingerUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo with a two-finger tap'**
  String get menuTwoFingerUndo;

  /// No description provided for @popEraserAutoRevert.
  ///
  /// In en, this message translates to:
  /// **'Return to the previous tool after erasing'**
  String get popEraserAutoRevert;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the note. Free up some space: it will retry automatically.'**
  String get saveFailed;

  /// No description provided for @tplHalfLetter.
  ///
  /// In en, this message translates to:
  /// **'Half Letter'**
  String get tplHalfLetter;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
