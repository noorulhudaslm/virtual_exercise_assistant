import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/diet_plan_types.dart';
import '../utils/meal_plan_query_builder.dart';
import '../utils/time_frame.dart';

class DietPlan extends StatefulWidget {
  const DietPlan({Key? key}) : super(key: key);

  @override
  DietPlanState createState() => DietPlanState();
}

class DietPlanState extends State<DietPlan> {
  List<dynamic>? _meals;
  MealPlanQueryResult? _queryResult;
  bool _isLoading = false;
  bool _shouldReset = false;

  // Dynamic field configuration for the meal plan query
  final List<MealPlanFieldConfig> _fieldConfigs = [
    MealPlanFieldConfig(
      label: 'Diet Type',
      key: 'diet',
      type: FieldType.enumDropdown,
      enumValues: DietType.values,
      isRequired: true,
      defaultValue: DietType.vegetarian,
    ),
    MealPlanFieldConfig(
      label: 'Time Frame',
      key: 'timeFrame',
      type: FieldType.enumDropdown,
      enumValues: TimeFrame.values,
      isRequired: true,
      defaultValue: TimeFrame.daily,
    ),
    MealPlanFieldConfig(
      label: 'Target Calories',
      key: 'targetCalories',
      type: FieldType.numberInput,
      placeholder: 'Enter daily calorie target',
      isRequired: true,
      defaultValue: '2000',
    ),
    MealPlanFieldConfig(
      label: 'Exclude Foods',
      key: 'exclude',
      type: FieldType.textInput,
      placeholder: 'Foods to exclude (e.g., shellfish, olives)',
      isRequired: false,
    ),
  ];

  void _onQueryChanged(MealPlanQueryResult result) {
    _queryResult = result;
  }

  Future<void> fetchBmi() async {
    if (_queryResult == null || !_queryResult!.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
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
      final dietType = _queryResult!.values['diet'] as DietType;
      final timeFrame = _queryResult!.values['timeFrame'] as TimeFrame;
      final targetCalories = _queryResult!.values['targetCalories'] as String;
      final exclude = _queryResult!.values['exclude'] as String?;

      // Convert enum to API format
      String dietString;
      switch (dietType) {
        case DietType.vegetarian:
          dietString = 'vegetarian';
          break;
        case DietType.vegan:
          dietString = 'vegan';
          break;
        case DietType.ketogenic:
          dietString = 'ketogenic';
          break;
        case DietType.paleo:
          dietString = 'paleo';
          break;
        case DietType.glutenfree:
          dietString = 'glutenfree';
          break;
        case DietType.pescetarian:
          dietString = 'pescetarian';
          break;
        case DietType.primal:
          dietString = 'primal';
          break;
        case DietType.lowfodmap:
          dietString = 'lowfodmap';
          break;
        case DietType.whole30:
          dietString = 'whole30';
          break;
      }

      // Convert time frame to API format
      String timeFrameString;
      switch (timeFrame) {
        case TimeFrame.daily:
          timeFrameString = 'day';
          break;
        case TimeFrame.weekly:
          timeFrameString = 'week';
          break;
      }

      final queryParams = <String, String>{
        'apiKey': '021748ec2536448ea4027200284b472a',
        'timeFrame': timeFrameString,
        'targetCalories': targetCalories,
        'diet': dietString,
      };

      // Add exclude parameter if provided
      if (exclude != null && exclude.isNotEmpty) {
        queryParams['exclude'] = exclude;
      }

      final url = Uri.https(
        'api.spoonacular.com',
        '/mealplanner/generate',
        queryParams,
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final meals = data['meals'] as List<dynamic>?;

        setState(() {
          _meals = meals;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Meal plan generated successfully for ${dietType.displayName} diet',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to fetch meal plan: ${response.statusCode}');
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
      _meals = null;
      _shouldReset = !_shouldReset; // Toggle to trigger reset
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Dynamic Meal Plan Generator',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: const Color.fromARGB(255, 92, 238, 222),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
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
            // Dynamic Meal Plan Query Builder
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meal Plan Configuration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    MealPlanQueryBuilder(
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
            ElevatedButton(
              onPressed: _isLoading ? null : fetchBmi,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 92, 238, 222),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                              Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Generating...',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Generate Meal Plan',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Results Display
            if (_queryResult != null) ...[
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Current Configuration:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _queryResult!.isValid
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _queryResult!.isValid ? 'Valid' : 'Invalid',
                              style: TextStyle(
                                color: _queryResult!.isValid
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[600]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _queryResult!.values.entries.map((entry) {
                            final value = entry.value;
                            String displayValue;

                            if (value is Enum) {
                              if (value is DietType) {
                                displayValue = value.displayName;
                              } else if (value is TimeFrame) {
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

            // Meals Display
            if (_meals != null && _meals!.isNotEmpty) ...[
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Meal Plan:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 400, // Fixed height for scrollable list
                        child: ListView.builder(
                          itemCount: _meals!.length,
                          itemBuilder: (context, index) {
                            final meal = _meals![index];
                            return GestureDetector(
                              onTap: () {
                                // You can add meal selection logic here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Selected: ${meal['title']}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: Card(
                                color: const Color.fromARGB(255, 92, 238, 222),
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meal['title'] ?? 'No Title',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Ready in: ${meal['readyInMinutes'] ?? 'N/A'} minutes',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.people,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Servings: ${meal['servings'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (meal['sourceUrl'] != null) ...[
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.link,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                'Recipe available',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
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
