enum TimeFrame { daily, weekly }

extension TimeFrameExtension on TimeFrame {
  String get displayName {
    switch (this) {
      case TimeFrame.daily:
        return 'Daily';
      case TimeFrame.weekly:
        return 'Weekly';
    }
  }
}