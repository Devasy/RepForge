Map<String, Object?> programToolFixture() => {
  'name': 'Two week strength plan',
  'description': 'Use recent tolerable loads; progress only when comfortable.',
  'totalWeeks': 2,
  'weeks': [
    for (var week = 1; week <= 2; week++)
      {
        'weekNumber': week,
        'days': [
          {
            'id': 'day-1',
            'name': 'Strength',
            'dayOfWeek': 1,
            'exercises': [
              {
                'exerciseId': 'bench_press',
                'sets': 3,
                'minReps': 8,
                'maxReps': 10,
                'restSeconds': 90,
                'tempo': '2-1-1',
                'notes': 'Keep comfortable effort.',
              },
            ],
          },
        ],
      },
  ],
};
