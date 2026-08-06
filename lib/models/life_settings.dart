class LifeSettings {
  final DateTime birthDate;
  final int lifeExpectancyYears;

  const LifeSettings({
    required this.birthDate,
    required this.lifeExpectancyYears,
  });

  DateTime get estimatedEndDate => DateTime(
        birthDate.year + lifeExpectancyYears,
        birthDate.month,
        birthDate.day,
      );

  LifeSettings copyWith({DateTime? birthDate, int? lifeExpectancyYears}) {
    return LifeSettings(
      birthDate: birthDate ?? this.birthDate,
      lifeExpectancyYears: lifeExpectancyYears ?? this.lifeExpectancyYears,
    );
  }
}
