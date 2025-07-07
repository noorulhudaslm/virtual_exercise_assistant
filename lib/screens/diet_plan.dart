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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2E3192), // Deep purple
            Color(0xFF1BFFFF), // Cyan
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Diet Plan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
                onPressed: _resetForm,
                tooltip: 'Reset Form',
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dynamic Meal Plan Query Builder
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.settings,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Generate Your Diet Plan',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                const SizedBox(height: 24),

                // Generate Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1BFFFF), Color(0xFF2E3192)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1BFFFF).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : fetchBmi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Generating...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Generate Meal Plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Results Display
                if (_queryResult != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Current Configuration',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
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
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
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
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          '${entry.key}:',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          displayValue,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
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
                  const SizedBox(height: 24),
                ],

                // Meals Display
                if (_meals != null && _meals!.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.restaurant_menu,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Your Meal Plan',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 400,
                            child: ListView.builder(
                              itemCount: _meals!.length,
                              itemBuilder: (context, index) {
                                final meal = _meals![index];
                                return GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Selected: ${meal['title']}'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            meal['title'] ?? 'No Title',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.access_time,
                                                  color: Colors.orange,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Ready in: ${meal['readyInMinutes'] ?? 'N/A'} minutes',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.people,
                                                  color: Colors.blue,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Servings: ${meal['servings'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (meal['sourceUrl'] != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.link,
                                                    color: Colors.green,
                                                    size: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Recipe available',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
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
        ),
      ),
    );
  }
}