import 'package:flutter/material.dart';

import 'diet_plan_types.dart';
import 'time_frame.dart';

/// Represents a field configuration for the meal plan query builder
class MealPlanFieldConfig {
  final String label;
  final String key;
  final FieldType type;
  final List<Enum>? enumValues;
  final String? placeholder;
  final TextInputType? inputType;
  final bool isRequired;
  final dynamic defaultValue;

  const MealPlanFieldConfig({
    required this.label,
    required this.key,
    required this.type,
    this.enumValues,
    this.placeholder,
    this.inputType,
    this.isRequired = false,
    this.defaultValue,
  });
}

/// Types of fields that can be rendered
enum FieldType { enumDropdown, textInput, numberInput }

/// Result data structure for the meal plan query
class MealPlanQueryResult {
  final Map<String, dynamic> values;
  final bool isValid;

  const MealPlanQueryResult({required this.values, required this.isValid});
}

/// A dynamic widget that builds meal plan query forms based on field configurations
class MealPlanQueryBuilder extends StatefulWidget {
  final List<MealPlanFieldConfig> fields;
  final Function(MealPlanQueryResult) onQueryChanged;
  final EdgeInsetsGeometry? padding;
  final double? spacing;
  final VoidCallback? onReset;

  const MealPlanQueryBuilder({
    super.key,
    required this.fields,
    required this.onQueryChanged,
    this.padding,
    this.spacing,
    this.onReset,
  });

  @override
  State<MealPlanQueryBuilder> createState() => _MealPlanQueryBuilderState();
}

class _MealPlanQueryBuilderState extends State<MealPlanQueryBuilder> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, GlobalKey<FormState>> _formKeys = {};

  void resetForm() {
    setState(() {
      _values.clear();
      for (final controller in _controllers.values) {
        controller.clear();
      }
      _initializeValues();
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  @override
  void didUpdateWidget(MealPlanQueryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onReset != oldWidget.onReset && widget.onReset != null) {
      resetForm();
    }
  }

  void _initializeValues() {
    for (final field in widget.fields) {
      if (field.type == FieldType.enumDropdown) {
        _values[field.key] = field.defaultValue ?? field.enumValues?.first;
      } else {
        _controllers[field.key] = TextEditingController(
          text: field.defaultValue?.toString() ?? '',
        );
        _values[field.key] = field.defaultValue?.toString() ?? '';
      }
      _formKeys[field.key] = GlobalKey<FormState>();
    }
    _notifyQueryChanged();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notifyQueryChanged() {
    final isValid = _validateForm();
    widget.onQueryChanged(
      MealPlanQueryResult(values: Map.from(_values), isValid: isValid),
    );
  }

  bool _validateForm() {
    for (final field in widget.fields) {
      if (field.isRequired) {
        if (field.type == FieldType.enumDropdown) {
          if (_values[field.key] == null) return false;
        } else {
          final value = _values[field.key]?.toString().trim();
          if (value == null || value.isEmpty) return false;
        }
      }
    }
    return true;
  }

  Widget _buildField(MealPlanFieldConfig field) {
    switch (field.type) {
      case FieldType.enumDropdown:
        return _buildEnumDropdown(field);
      case FieldType.textInput:
        return _buildTextInput(field);
      case FieldType.numberInput:
        return _buildNumberInput(field);
    }
  }

  Widget _buildEnumDropdown(MealPlanFieldConfig field) {
    return Form(
      key: _formKeys[field.key],

      child: DropdownButtonFormField<Enum>(
        value: _values[field.key],
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: field.label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFF1BFFFF)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items:
            field.enumValues?.map((enumValue) {
              return DropdownMenuItem<Enum>(
                value: enumValue,
                child: Text(
                  _getEnumDisplayName(enumValue),
                  style: TextStyle(color: Colors.white),
                ),
              );
            }).toList() ??
            [],
        dropdownColor: Colors.black,
        onChanged: (value) {
          setState(() {
            _values[field.key] = value;
          });
          _notifyQueryChanged();
        },
        validator: field.isRequired
            ? (value) => value == null ? '${field.label} is required' : null
            : null,
      ),
    );
  }

  Widget _buildTextInput(MealPlanFieldConfig field) {
    return Form(
      key: _formKeys[field.key],
      child: TextFormField(
        controller: _controllers[field.key],
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: field.label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          hintText: field.placeholder,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFF1BFFFF)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        keyboardType: field.inputType ?? TextInputType.text,
        onChanged: (value) {
          _values[field.key] = value;
          _notifyQueryChanged();
        },
        validator: field.isRequired
            ? (value) => value?.trim().isEmpty == true
                  ? '${field.label} is required'
                  : null
            : null,
      ),
    );
  }

  Widget _buildNumberInput(MealPlanFieldConfig field) {
    return Form(
      key: _formKeys[field.key],
      child: TextFormField(
        controller: _controllers[field.key],
        style: TextStyle(color: Colors.white),

        decoration: InputDecoration(
          labelText: field.label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          hintText: field.placeholder,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFF1BFFFF)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          _values[field.key] = value;
          _notifyQueryChanged();
        },
        validator: field.isRequired
            ? (value) {
                if (value?.trim().isEmpty == true) {
                  return '${field.label} is required';
                }
                if (value != null && double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              }
            : null,
      ),
    );
  }

  String _getEnumDisplayName(Enum enumValue) {
    if (enumValue is DietType) {
      return enumValue.displayName;
    } else if (enumValue is TimeFrame) {
      return enumValue.displayName;
    }
    return enumValue.name;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding ?? const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < widget.fields.length; i++) ...[
            _buildField(widget.fields[i]),
            if (i < widget.fields.length - 1)
              SizedBox(height: widget.spacing ?? 16.0),
          ],
        ],
      ),
    );
  }
}

/// Helper class to create common meal plan field configurations
class MealPlanFieldConfigs {
  static List<MealPlanFieldConfig> get defaultConfig => [
    MealPlanFieldConfig(
      label: 'Diet Type',
      key: 'dietType',
      type: FieldType.enumDropdown,
      enumValues: DietType.values,
      isRequired: true,
    ),
    MealPlanFieldConfig(
      label: 'Time Frame',
      key: 'timeFrame',
      type: FieldType.enumDropdown,
      enumValues: TimeFrame.values,
      isRequired: true,
    ),
    MealPlanFieldConfig(
      label: 'Target Calories',
      key: 'targetCalories',
      type: FieldType.numberInput,
      placeholder: 'Enter daily calorie target',
      isRequired: true,
    ),
  ];

  static List<MealPlanFieldConfig> get customConfig => [
    MealPlanFieldConfig(
      label: 'Diet Type',
      key: 'dietType',
      type: FieldType.enumDropdown,
      enumValues: DietType.values,
      isRequired: true,
    ),
    MealPlanFieldConfig(
      label: 'Time Frame',
      key: 'timeFrame',
      type: FieldType.enumDropdown,
      enumValues: TimeFrame.values,
      isRequired: true,
    ),
    MealPlanFieldConfig(
      label: 'Target Calories',
      key: 'targetCalories',
      type: FieldType.numberInput,
      placeholder: 'Enter daily calorie target',
      isRequired: true,
    ),
    MealPlanFieldConfig(
      label: 'Allergies',
      key: 'allergies',
      type: FieldType.textInput,
      placeholder: 'Enter any food allergies (optional)',
      isRequired: false,
    ),
    MealPlanFieldConfig(
      label: 'Preferences',
      key: 'preferences',
      type: FieldType.textInput,
      placeholder: 'Enter food preferences (optional)',
      isRequired: false,
    ),
  ];
}