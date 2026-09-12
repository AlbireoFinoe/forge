class WeekdayOption {
  const WeekdayOption({
    required this.value,
    required this.shortLabel,
    required this.label,
  });

  final int value;
  final String shortLabel;
  final String label;
}

const weekdays = <WeekdayOption>[
  WeekdayOption(value: 1, shortLabel: 'Mon', label: 'Monday'),
  WeekdayOption(value: 2, shortLabel: 'Tue', label: 'Tuesday'),
  WeekdayOption(value: 3, shortLabel: 'Wed', label: 'Wednesday'),
  WeekdayOption(value: 4, shortLabel: 'Thu', label: 'Thursday'),
  WeekdayOption(value: 5, shortLabel: 'Fri', label: 'Friday'),
  WeekdayOption(value: 6, shortLabel: 'Sat', label: 'Saturday'),
  WeekdayOption(value: 7, shortLabel: 'Sun', label: 'Sunday'),
];

String weekdayLabel(int value) {
  for (final day in weekdays) {
    if (day.value == value) {
      return day.label;
    }
  }

  return 'Unknown day';
}
