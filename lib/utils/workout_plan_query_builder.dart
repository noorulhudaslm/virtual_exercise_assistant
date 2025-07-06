import 'package:flutter/material.dart';

import 'workout_plan_types.dart';

/// Represents a field configuration for the workout plan query builder
class WorkoutPlanFieldConfig {
  final String label;
  final String key;
  final FieldType type;
  final List<Enum>? enumValues;
  final String? placeholder;
  final TextInputType? inputType;
  final bool isRequired;
  final dynamic defaultValue;

  const WorkoutPlanFieldConfig({
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

/// Result data structure for the workout plan query
class WorkoutPlanQueryResult {
  final Map<String, dynamic> values;
  final bool isValid;

  const WorkoutPlanQueryResult({required this.values, required this.isValid});
}

/// A dynamic widget that builds workout plan query forms based on field configurations
class WorkoutPlanQueryBuilder extends StatefulWidget {
  final List<WorkoutPlanFieldConfig> fields;
  final Function(WorkoutPlanQueryResult) onQueryChanged;
  final EdgeInsetsGeometry? padding;
  final double? spacing;
  final VoidCallback? onReset;

  const WorkoutPlanQueryBuilder({
    super.key,
    required this.fields,
    required this.onQueryChanged,
    this.padding,
    this.spacing,
    this.onReset,
  });

  @override
  State<WorkoutPlanQueryBuilder> createState() =>
      _WorkoutPlanQueryBuilderState();
}

class _WorkoutPlanQueryBuilderState extends State<WorkoutPlanQueryBuilder> {
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
  void didUpdateWidget(WorkoutPlanQueryBuilder oldWidget) {
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
      WorkoutPlanQueryResult(values: Map.from(_values), isValid: isValid),
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

  Widget _buildField(WorkoutPlanFieldConfig field) {
    switch (field.type) {
      case FieldType.enumDropdown:
        return _buildEnumDropdown(field);
      case FieldType.textInput:
        return _buildTextInput(field);
      case FieldType.numberInput:
        return _buildNumberInput(field);
    }
  }

  Widget _buildEnumDropdown(WorkoutPlanFieldConfig field) {
    return Form(
      key: _formKeys[field.key],
      child: DropdownButtonFormField<Enum>(
        value: _values[field.key],
        style: const TextStyle(color: Colors.white),
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
            borderSide: const BorderSide(color: Color(0xFF1BFFFF)),
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
                  style: const TextStyle(color: Colors.white),
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

  Widget _buildTextInput(WorkoutPlanFieldConfig field) {
    return Form(
      key: _formKeys[field.key],
      child: TextFormField(
        controller: _controllers[field.key],
        style: const TextStyle(color: Colors.white),
        keyboardType: field.inputType ?? TextInputType.text,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.placeholder,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
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
            borderSide: const BorderSide(color: Color(0xFF1BFFFF)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _values[field.key] = value;
          });
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

  Widget _buildNumberInput(WorkoutPlanFieldConfig field) {
    return Form(
      key: _formKeys[field.key],
      child: TextFormField(
        controller: _controllers[field.key],
        style: const TextStyle(color: Colors.white),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.placeholder,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
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
            borderSide: const BorderSide(color: Color(0xFF1BFFFF)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _values[field.key] = value;
          });
          _notifyQueryChanged();
        },
        validator: field.isRequired
            ? (value) {
                if (value?.trim().isEmpty == true) {
                  return '${field.label} is required';
                }
                if (value != null && int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              }
            : null,
      ),
    );
  }

  String _getEnumDisplayName(Enum enumValue) {
    if (enumValue is ExerciseMuscleGroup) {
      return enumValue.displayName;
    } else if (enumValue is ExerciseType) {
      return enumValue.displayName;
    } else if (enumValue is ExerciseDifficulty) {
      return enumValue.displayName;
    }
    return enumValue.name;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.fields.map((field) {
        final index = widget.fields.indexOf(field);
        return Column(
          children: [
            _buildField(field),
            if (index < widget.fields.length - 1 && widget.spacing != null)
              SizedBox(height: widget.spacing),
          ],
        );
      }).toList(),
    );
  }
}
