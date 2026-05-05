abstract final class AppStrings {
  static const settingsTitle = 'Settings';
  static const profileTitle = 'Profile';
  static const profileSubtitle =
      'Edit account code and future profile settings.';
  static const fromTownTitle = 'From Town';
  static const fromTownSubtitle =
      'Choose the default source town for the form.';
  static const voucherHeaderTitle = 'Voucher Header';
  static const voucherHeaderSubtitle =
      'Edit the address and phone shown on the voucher header.';
  static const receiptSettingsTitle = 'Receipt Settings';
  static const receiptSettingsSubtitle =
      'Live preview, font size, and receipt padding controls.';
  static const labelSettingsTitle = 'Label Settings';
  static const labelSettingsSubtitle =
      'Adjust the 70x50 parcel label preview and spacing.';
  static const toTownTitle = 'To Town';
  static const toTownSubtitle = 'Add or remove destination towns.';
  static const printerSettingsTitle = 'Printer Settings';
  static const printerSettingsSubtitle =
      'Choose the printer preset used for receipt output.';
  static const backupRestoreTitle = 'Backup and Restore';
  static const backupRestoreSubtitle =
      'Manage local parcel data backup and restore tools.';
  static const fullBackupTitle = 'Full Backup';
  static const fullBackupSubtitle =
      'Create a zip backup with the SQLite database and parcel images.';
  static const lightBackupTitle = 'Light Backup';
  static const lightBackupSubtitle =
      'Create a backup that includes the SQLite database only.';
  static const restoreBackupTitle = 'Restore Backup';
  static const restoreBackupSubtitle =
      'Restore parcel data from a light backup or a full zip backup.';
  static const noBackupFilesFound =
      'No backup files were found in the TKT Parcel Backups folder.';
  static const chooseBackupFileTitle = 'Choose Backup File';
  static const chooseBackupFileSubtitle =
      'Select a saved .zip or database backup file to restore.';
  static const backupPermissionBlocked =
      'Storage permission is blocked. Open Android settings and allow file access first.';
  static const appVersionTitle = 'App Version';

  static const headerFontSizeTitle = 'Header Font Size';
  static const bodyFontSizeTitle = 'Body Font Size';
  static const receiptPaddingTitle = 'Receipt Padding';
  static const livePreviewTitle = 'Live Preview';
  static const saveReceiptSettings = 'Save Receipt Settings';
  static const receiptSettingsSaved = 'Receipt settings saved.';
  static const saveLabelSettings = 'Save Label Settings';
  static const labelSettingsSaved = 'Label settings saved.';

  static const titleLabel = 'Title';
  static const subtitleLabel = 'Subtitle';
  static const addressLabel = 'Address';
  static const phoneLabel = 'Phone';
  static const phoneNumbersLabel = 'Phone Numbers';
  static const labelLabel = 'Label';
  static const valueLabel = 'Value';
  static const topLabel = 'Top';
  static const horizontalLabel = 'Horizontal';
  static const bottomLabel = 'Bottom';
  static const rowGapLabel = 'Row Gap';
  static const bodyLabel = 'Body';

  static const voucherHeaderSaved = 'Voucher header settings saved.';
  static const saveChanges = 'Save Changes';
  static const requiredField = 'Required.';
  static const accountCodeLabel = 'Account Code';
  static const profileSaved = 'Profile settings saved.';

  static const noSourceTowns = 'No source towns available.';
  static const defaultFromTownUpdated = 'Default from town updated.';
  static const newDestinationTownLabel = 'New destination town';
  static const addAction = 'Add';
  static const deleteToTownTitle = 'Delete To Town';
  static const cancelAction = 'Cancel';
  static const deleteAction = 'Delete';

  static const printerPresetLight = 'Light';
  static const printerPresetLightSubtitle =
      'Lighter print density for thin paper or sharp black text.';
  static const printerPresetBalanced = 'Balanced';
  static const printerPresetBalancedSubtitle =
      'Recommended default for most receipts.';
  static const printerPresetDark = 'Dark';
  static const printerPresetDarkSubtitle =
      'Darker print density for bold output.';
}
