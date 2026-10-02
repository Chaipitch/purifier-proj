// Standard Salesforce pages show Buddhist years (2569) to users whose Locale is Thai (th_TH).
// This moves those users to English (United Kingdom): dd/MM/yyyy dates with AD years. Their
// language, time zone and currency stay as they are. Site guest users are left alone.
// Run as a System Administrator: sf apex run --target-org noritz --file scripts/apex/use_gregorian_locale.apex
List<User> thaiLocale = [
  SELECT Id, Username, LocaleSidKey
  FROM User
  WHERE IsActive = TRUE AND LocaleSidKey = 'th_TH' AND UserType != 'Guest'
];
for (User u : thaiLocale) {
  u.LocaleSidKey = 'en_GB';
  System.debug(LoggingLevel.WARN, 'Locale -> en_GB: ' + u.Username);
}
update thaiLocale;
System.debug(LoggingLevel.WARN, thaiLocale.size() + ' user(s) updated.');
