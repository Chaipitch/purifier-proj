// Date helpers that always work in the Gregorian (AD) calendar.
// For a user with the Thai (th_TH) locale, Apex uses the Buddhist calendar: Date.year() returns
// 2569, and Date.newInstance(2026, ...) and toStartOfMonth() save dates 543 years out. These
// helpers work from the ISO yyyy-MM-dd string, which is always AD whatever the user's locale.
public inherited sharing class GregorianDates {
  private static final List<String> MONTHS = new List<String>{
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  };

  // First day of d's month.
  public static Date startOfMonth(Date d) {
    List<Integer> ymd = parts(d);
    return build(ymd[0], ymd[1], 1);
  }

  // d plus n months (n may be negative). The day is capped at the end of the month:
  // 31 Jan + 1 month is 28 Feb (29 Feb in a leap year).
  public static Date addMonths(Date d, Integer n) {
    List<Integer> ymd = parts(d);
    Integer months = ymd[0] * 12 + (ymd[1] - 1) + n;
    Integer year = months / 12;
    Integer month = Math.mod(months, 12) + 1;
    return build(year, month, Math.min(ymd[2], daysInMonth(year, month)));
  }

  // "7 Oct 2026".
  public static String format(Date d) {
    List<Integer> ymd = parts(d);
    return ymd[2] + ' ' + MONTHS[ymd[1] - 1] + ' ' + ymd[0];
  }

  // String.valueOf(Date) is ISO yyyy-MM-dd in the Gregorian calendar for every locale.
  private static List<Integer> parts(Date d) {
    List<String> p = String.valueOf(d).split('-');
    return new List<Integer>{
      Integer.valueOf(p[0]),
      Integer.valueOf(p[1]),
      Integer.valueOf(p[2])
    };
  }

  private static Date build(Integer year, Integer month, Integer day) {
    return Date.valueOf(
      String.valueOf(year).leftPad(4, '0') +
        '-' +
        String.valueOf(month).leftPad(2, '0') +
        '-' +
        String.valueOf(day).leftPad(2, '0')
    );
  }

  private static Integer daysInMonth(Integer year, Integer month) {
    if (month == 2) {
      Boolean leap =
        (Math.mod(year, 4) == 0 && Math.mod(year, 100) != 0) ||
        Math.mod(year, 400) == 0;
      return leap ? 29 : 28;
    }
    return new Set<Integer>{ 4, 6, 9, 11 }.contains(month) ? 30 : 31;
  }
}
