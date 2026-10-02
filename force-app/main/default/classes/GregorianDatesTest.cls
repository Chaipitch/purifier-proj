@IsTest
private class GregorianDatesTest {
  @IsTest
  static void startOfMonth() {
    Assert.areEqual(
      '2026-10-01',
      String.valueOf(GregorianDates.startOfMonth(Date.valueOf('2026-10-02')))
    );
  }

  @IsTest
  static void addMonthsCapsTheDayAndCrossesYears() {
    Assert.areEqual(
      '2027-01-15',
      String.valueOf(GregorianDates.addMonths(Date.valueOf('2026-10-15'), 3))
    );
    Assert.areEqual(
      '2026-07-02',
      String.valueOf(GregorianDates.addMonths(Date.valueOf('2026-10-02'), -3))
    );
    Assert.areEqual(
      '2027-02-28',
      String.valueOf(GregorianDates.addMonths(Date.valueOf('2027-01-31'), 1))
    );
    Assert.areEqual(
      '2028-02-29',
      String.valueOf(GregorianDates.addMonths(Date.valueOf('2028-01-31'), 1))
    );
    Assert.areEqual(
      '2026-04-30',
      String.valueOf(GregorianDates.addMonths(Date.valueOf('2026-03-31'), 1))
    );
  }

  @IsTest
  static void formatsInAd() {
    Assert.areEqual(
      '7 Oct 2026',
      GregorianDates.format(Date.valueOf('2026-10-07'))
    );
  }

  // The reason the class exists: a Thai-locale user still gets AD years, not 2569.
  @IsTest
  static void thaiLocaleUserGetsAdYears() {
    User thai = new User(
      ProfileId = UserInfo.getProfileId(),
      LastName = 'Thai Locale',
      Alias = 'thloc',
      Email = 'thai.locale@example.com',
      Username = 'thai.locale.' + System.currentTimeMillis() + '@example.com',
      LocaleSidKey = 'th_TH',
      LanguageLocaleKey = 'en_US',
      TimeZoneSidKey = 'Asia/Bangkok',
      EmailEncodingKey = 'UTF-8'
    );
    System.runAs(thai) {
      Date d = Date.valueOf('2026-10-02');
      Assert.areEqual(
        '2026-10-01',
        String.valueOf(GregorianDates.startOfMonth(d))
      );
      Assert.areEqual(
        '2027-10-02',
        String.valueOf(GregorianDates.addMonths(d, 12))
      );
      Assert.areEqual('2 Oct 2026', GregorianDates.format(d));
    }
  }
}
