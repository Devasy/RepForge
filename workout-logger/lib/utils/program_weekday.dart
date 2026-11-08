const programWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String? programWeekday(int? day) =>
    day != null && day >= 1 && day <= 7 ? programWeekdays[day - 1] : null;
