enum DietType {
  glutenfree,
  pescetarian,
  vegetarian,
  vegan,
  primal,
  ketogenic,
  paleo,
  lowfodmap,
  whole30,
}

extension DietTypeExtension on DietType {
  String get displayName {
    switch (this) {
      case DietType.glutenfree:
        return 'Gluten Free';
      case DietType.pescetarian:
        return 'Pescetarian';
      case DietType.vegetarian:
        return 'Vegetarian';
      case DietType.vegan:
        return 'Vegan';
      case DietType.primal:
        return 'Primal';
      case DietType.ketogenic:
        return 'Ketogenic';
      case DietType.paleo:
        return 'Paleo';
      case DietType.lowfodmap:
        return 'Low FODMAP';
      case DietType.whole30:
        return 'Whole30';
    }
  }
}