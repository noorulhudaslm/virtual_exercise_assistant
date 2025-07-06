import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/workout_plan_types.dart';
import '../utils/workout_plan_query_builder.dart';

class WorkoutPlan extends StatefulWidget {
  const WorkoutPlan({Key? key}) : super(key: key);

  @override
  WorkoutPlanState createState() => WorkoutPlanState();
}

class WorkoutPlanState extends State<WorkoutPlan> {
  List<dynamic>? _workouts;
  WorkoutPlanQueryResult? _queryResult;
  bool _isLoading = false;
  bool _shouldReset = false;

  // API Key
  static const String _apiKey = 'sPn9Kcp+LdPz9Etw5vEzUg==58qz1KOtAkZCpD0q';

  // Dynamic field configuration for the workout plan query
  final List<WorkoutPlanFieldConfig> _fieldConfigs = [
    WorkoutPlanFieldConfig(
      label: 'Target Muscle Group',
      key: 'muscle',
      type: FieldType.enumDropdown,
      enumValues: ExerciseMuscleGroup.values,
      isRequired: true,
      defaultValue: ExerciseMuscleGroup.chest,
    ),
    WorkoutPlanFieldConfig(
      label: 'Exercise Type',
      key: 'type',
      type: FieldType.enumDropdown,
      enumValues: ExerciseType.values,
      isRequired: true,
      defaultValue: ExerciseType.strength,
    ),
    WorkoutPlanFieldConfig(
      label: 'Difficulty Level',
      key: 'difficulty',
      type: FieldType.enumDropdown,
      enumValues: ExerciseDifficulty.values,
      isRequired: true,
      defaultValue: ExerciseDifficulty.beginner,
    ),
  ];

  void _onQueryChanged(WorkoutPlanQueryResult result) {
    _queryResult = result;
  }

  Future<void> generateWorkoutPlan() async {
    if (_queryResult == null || !_queryResult!.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if API key is configured
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please configure your API key in the workout_plan.dart file',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert enum values to API-compatible strings
      final muscle = _queryResult!.values['muscle'] as ExerciseMuscleGroup;
      final type = _queryResult!.values['type'] as ExerciseType;
      final difficulty =
          _queryResult!.values['difficulty'] as ExerciseDifficulty;

      // Build request body
      final requestBody = {
        'muscle': muscle.name,
        'type': type.name,
        'difficulty': difficulty.name,
      };

      // Build query parameters for API Ninjas
      final queryParams = {
        'muscle': muscle.name,
        'type': type.name,
        'difficulty': difficulty.name,
      };

      // Make API request with proper headers for API Ninjas
      final response = await http.get(
        Uri.parse(
          'https://api.api-ninjas.com/v1/exercises',
        ).replace(queryParameters: queryParams),
        headers: {
          'X-Api-Key': _apiKey, // API Ninjas uses X-Api-Key header
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> exercises =
            jsonDecode(response.body) as List<dynamic>;

        setState(() {
          _workouts = exercises;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${exercises.length} exercises for ${muscle.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key. Please check your configuration.');
      } else if (response.statusCode == 403) {
        throw Exception(
          'Access forbidden. Please check your API key and permissions.',
        );
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded. Please try again later.');
      } else {
        throw Exception(
          'Failed to generate workout plan: ${response.statusCode}',
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _queryResult = null;
      _workouts = null;
      _shouldReset = !_shouldReset; // Toggle to trigger reset
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E3192),
      appBar: AppBar(
        title: const Text(
          'Workout Plan Generator',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5494DD),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetForm,
            tooltip: 'Reset Form',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dynamic Workout Plan Query Builder
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5494DD), Color(0xFF2E3192)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Workout Plan Configuration',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    WorkoutPlanQueryBuilder(
                      fields: _fieldConfigs,
                      onQueryChanged: _onQueryChanged,
                      spacing: 20.0,
                      onReset: _shouldReset ? () {} : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Generate Button
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5494DD), Color(0xFF1BFFFF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5494DD).withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : generateWorkoutPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Generating...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Generate Workout Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Results Display
            if (_queryResult != null) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF5494DD).withOpacity(0.8),
                      const Color(0xFF2E3192).withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Current Configuration:',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _queryResult!.isValid
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _queryResult!.isValid
                                    ? Colors.green
                                    : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _queryResult!.isValid ? 'Valid' : 'Invalid',
                              style: TextStyle(
                                color: _queryResult!.isValid
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _queryResult!.values.entries.map((entry) {
                            final value = entry.value;
                            String displayValue;

                            if (value is Enum) {
                              if (value is ExerciseMuscleGroup) {
                                displayValue = value.displayName;
                              } else if (value is ExerciseType) {
                                displayValue = value.displayName;
                              } else if (value is ExerciseDifficulty) {
                                displayValue = value.displayName;
                              } else {
                                displayValue = value.name;
                              }
                            } else {
                              displayValue = value?.toString() ?? 'Not set';
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      '${entry.key}:',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      displayValue,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Workouts Display
            if (_workouts != null && _workouts!.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF5494DD).withOpacity(0.8),
                      const Color(0xFF2E3192).withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Your Workout Plan:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 400, // Fixed height for scrollable list
                        child: ListView.builder(
                          itemCount: _workouts!.length,
                          itemBuilder: (context, index) {
                            final workout = _workouts![index];
                            return GestureDetector(
                              onTap: () {
                                // You can add workout selection logic here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Selected: ${workout['name']}',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1BFFFF),
                                      Color(0xFF5494DD),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1BFFFF,
                                      ).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        workout['name'] ?? 'No Title',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (workout['type'] != null) ...[
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.category,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Type: ${workout['type']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                      ],
                                      if (workout['muscle'] != null) ...[
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.fitness_center,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Muscle: ${workout['muscle']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                      ],
                                      if (workout['equipment'] != null) ...[
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.build,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                'Equipment: ${workout['equipment']}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (workout['difficulty'] != null) ...[
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.trending_up,
                                              color: Colors.purple,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Difficulty: ${workout['difficulty']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                      ],
                                      if (workout['instructions'] != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Instructions: ${workout['instructions']}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
