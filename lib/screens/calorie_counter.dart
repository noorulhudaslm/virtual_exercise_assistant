import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../drawer/app_drawer.dart';
import 'dart:convert';

class CalorieCounter extends StatefulWidget {
  @override
  _CalorieCounterState createState() => _CalorieCounterState();
}

class _CalorieCounterState extends State<CalorieCounter>
    with TickerProviderStateMixin {
  final _foodController = TextEditingController();
  final _quantityController = TextEditingController();
  List<Map<String, dynamic>> _foodItems = [];
  double _totalCalories = 0;
  double _totalProtein = 0;
  double _totalCarbs = 0;
  double _totalFat = 0;
  bool _isLoading = false;

  // Daily goals
  double _dailyCalorieGoal = 2000;
  String _selectedMeal = 'Breakfast';
  final List<String> _meals = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // USDA FoodData Central API configuration
  String _apiKey = '67bBBXvV8JpSsbSwbNgTGr3MYYOlrYAuErgEefSQ';
  final String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  // Search results for food selection
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _quantityController.text = '100'; // Default to 100g
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E3192), // Deep purple
              Color(0xFF1BFFFF), // Cyan
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AppDrawer(),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: Text(
                        'CALORIE TRACKER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Daily Progress Card
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'DAILY PROGRESS',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 16),

                            // Calorie Progress Ring
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 180,
                                  height: 180,
                                  child: AnimatedBuilder(
                                    animation: _progressAnimation,
                                    builder: (context, child) {
                                      return CircularProgressIndicator(
                                        value:
                                            (_totalCalories / _dailyCalorieGoal)
                                                .clamp(0.0, 1.0) *
                                            _progressAnimation.value,
                                        strokeWidth: 10,
                                        backgroundColor: Colors.white
                                            .withOpacity(0.2),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Color(0xFF00E5FF),
                                            ),
                                      );
                                    },
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${_totalCalories.toInt()}',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'of ${_dailyCalorieGoal.toInt()} kcal',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // Macronutrients Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildMacroItem(
                                  'Protein',
                                  _totalProtein,
                                  'g',
                                  Color(0xFF00E5FF),
                                ),
                                _buildMacroItem(
                                  'Carbs',
                                  _totalCarbs,
                                  'g',
                                  Color(0xFF00E5FF),
                                ),
                                _buildMacroItem(
                                  'Fat',
                                  _totalFat,
                                  'g',
                                  Color(0xFF00E5FF),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Food Search Section
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'ADD FOOD ITEM',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),

                            // Meal Selection
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedMeal,
                                dropdownColor: Color(0xFF2E3192),
                                style: TextStyle(color: Colors.white),
                                underline: SizedBox(),
                                isExpanded: true,
                                items: _meals.map((meal) {
                                  return DropdownMenuItem(
                                    value: meal,
                                    child: Text(meal),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMeal = value!;
                                  });
                                },
                              ),
                            ),

                            SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _foodController,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Search for food...',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.1),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value.length > 2) {
                                        _searchFoodDebounced(value);
                                      } else {
                                        setState(() {
                                          _showSearchResults = false;
                                          _searchResults.clear();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _quantityController,
                                    style: TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'g',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.1),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,2}'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Search results dropdown
                            if (_showSearchResults && _searchResults.isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2E3192).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final item = _searchResults[index];
                                    return ListTile(
                                      title: Text(
                                        item['description'] ?? 'Unknown Food',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        'Brand: ${item['brandOwner'] ?? 'Generic'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                      onTap: () => _selectFoodItem(item),
                                    );
                                  },
                                ),
                              ),

                            if (_isLoading)
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Food Items List
                      if (_foodItems.isEmpty)
                        Column(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 60,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No food items added yet',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 18,
                              ),
                            ),
                          ],
                        )
                      else
                        ..._buildMealSections(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroItem(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  List<Widget> _buildMealSections() {
    Map<String, List<Map<String, dynamic>>> mealGroups = {};

    for (var item in _foodItems) {
      String meal = item['meal'] ?? 'Other';
      if (!mealGroups.containsKey(meal)) {
        mealGroups[meal] = [];
      }
      mealGroups[meal]!.add(item);
    }

    List<Widget> sections = [];

    for (String meal in _meals) {
      if (mealGroups.containsKey(meal) && mealGroups[meal]!.isNotEmpty) {
        double mealCalories = mealGroups[meal]!.fold(
          0.0,
          (sum, item) => sum + (item['calories'] ?? 0.0),
        );

        sections.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16),
              Text(
                meal.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ...mealGroups[meal]!
                        .map((item) => _buildFoodItem(item))
                        .toList(),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${mealCalories.toInt()} kcal',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }

    return sections;
  }

  Widget _buildFoodItem(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown Food',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (item['protein'] != null)
                      Text(
                        'P: ${(item['protein'] ?? 0.0).toStringAsFixed(1)}g',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    if (item['carbs'] != null)
                      Text(
                        'C: ${(item['carbs'] ?? 0.0).toStringAsFixed(1)}g',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    if (item['fat'] != null)
                      Text(
                        'F: ${(item['fat'] ?? 0.0).toStringAsFixed(1)}g',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            children: [
              Text(
                '${(item['calories'] ?? 0.0).toInt()} kcal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white.withOpacity(0.7)),
                onPressed: () => _removeFood(_foodItems.indexOf(item)),
                constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Debounce function to avoid too many API calls
  void _searchFoodDebounced(String query) async {
    await Future.delayed(Duration(milliseconds: 500));
    if (_foodController.text == query) {
      _searchFood(query);
    }
  }

  Future<void> _searchFood(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/foods/search?api_key=$_apiKey&query=${Uri.encodeComponent(query)}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      print('Search Response status: ${response.statusCode}');
      print('Search Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['foods'] != null && data['foods'].isNotEmpty) {
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(
              data['foods'].take(10),
            );
            _showSearchResults = true;
          });
        } else {
          _showErrorMessage('No food items found for "$query"');
          setState(() {
            _searchResults.clear();
            _showSearchResults = false;
          });
        }
      } else {
        _handleApiError(response.statusCode, response.body);
      }
    } catch (e) {
      print('Search Error: $e');
      _showErrorMessage('Network error during search: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFoodItem(Map<String, dynamic> selectedFood) async {
    setState(() {
      _showSearchResults = false;
      _isLoading = true;
    });

    try {
      int fdcId = selectedFood['fdcId'];
      final response = await http.get(
        Uri.parse('$_baseUrl/food/$fdcId?api_key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Food Details Response status: ${response.statusCode}');
      print('Food Details Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        double quantity = double.tryParse(_quantityController.text) ?? 100;

        // Extract nutritional information
        Map<String, double> nutrients = _extractNutrients(
          data['foodNutrients'] ?? [],
        );

        // Scale nutrients to requested quantity (nutrients are per 100g)
        double scaleFactor = quantity / 100.0;

        final foodItem = <String, dynamic>{
          'name':
              (data['description'] ??
                      selectedFood['description'] ??
                      'Unknown Food')
                  .toString(),
          'brand': (data['brandOwner'] ?? selectedFood['brandOwner'] ?? '')
              .toString(),
          'calories': (nutrients['calories'] ?? 0.0) * scaleFactor,
          'protein': (nutrients['protein'] ?? 0.0) * scaleFactor,
          'carbs': (nutrients['carbs'] ?? 0.0) * scaleFactor,
          'fat': (nutrients['fat'] ?? 0.0) * scaleFactor,
          'meal': _selectedMeal,
          'quantity': quantity,
          'fdcId': fdcId,
          'timestamp': DateTime.now(),
        };

        _addFoodItem(foodItem);
      } else {
        _handleApiError(response.statusCode, response.body);
      }
    } catch (e) {
      print('Food Details Error: $e');
      _showErrorMessage('Error getting food details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, double> _extractNutrients(List<dynamic> foodNutrients) {
    Map<String, double> nutrients = {
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
    };

    for (var nutrient in foodNutrients) {
      if (nutrient['nutrient'] != null && nutrient['amount'] != null) {
        String name = nutrient['nutrient']['name']?.toLowerCase() ?? '';
        int? id = nutrient['nutrient']['id'];
        double amount = (nutrient['amount'] ?? 0.0).toDouble();

        // Map USDA nutrient IDs to our categories
        if (id == 1008 || name.contains('energy') || name.contains('calorie')) {
          nutrients['calories'] = amount;
        } else if (id == 1003 || name.contains('protein')) {
          nutrients['protein'] = amount;
        } else if (id == 1005 || name.contains('carbohydrate')) {
          nutrients['carbs'] = amount;
        } else if (id == 1004 ||
            name.contains('total lipid') ||
            name.contains('fat')) {
          nutrients['fat'] = amount;
        }
      }
    }

    return nutrients;
  }

  void _addFoodItem(Map<String, dynamic> foodItem) {
    setState(() {
      _foodItems.add(foodItem);
      _totalCalories += foodItem['calories'] ?? 0.0;
      _totalProtein += foodItem['protein'] ?? 0.0;
      _totalCarbs += foodItem['carbs'] ?? 0.0;
      _totalFat += foodItem['fat'] ?? 0.0;
      _foodController.clear();
      _quantityController.text = '100';
      _searchResults.clear();
    });

    _animationController.reset();
    _animationController.forward();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${foodItem['name']} - ${(foodItem['calories'] ?? 0.0).toInt()} kcal',
        ),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  void _handleApiError(int statusCode, String responseBody) {
    String message;
    switch (statusCode) {
      case 400:
        message = 'Invalid request. Please check your search terms.';
        break;
      case 401:
        message = 'API key is invalid. Please check your USDA API key.';
        break;
      case 403:
        message = 'Access forbidden. Check your API key permissions.';
        break;
      case 429:
        message = 'Too many requests. Please wait a moment and try again.';
        break;
      case 404:
        message = 'Food item not found.';
        break;
      default:
        message = 'Server error ($statusCode). Please try again later.';
    }

    print('API Error - Status: $statusCode, Body: $responseBody');
    _showErrorMessage(message);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _removeFood(int index) {
    final item = _foodItems[index];
    setState(() {
      _totalCalories -= item['calories'] ?? 0.0;
      _totalProtein -= item['protein'] ?? 0.0;
      _totalCarbs -= item['carbs'] ?? 0.0;
      _totalFat -= item['fat'] ?? 0.0;
      _foodItems.removeAt(index);
    });

    _animationController.reset();
    _animationController.forward();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${item['name'] ?? "food item"}'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() {
              _foodItems.insert(index, item);
              _totalCalories += item['calories'] ?? 0.0;
              _totalProtein += item['protein'] ?? 0.0;
              _totalCarbs += item['carbs'] ?? 0.0;
              _totalFat += item['fat'] ?? 0.0;
            });
            _animationController.reset();
            _animationController.forward();
          },
        ),
      ),
    );
  }

  void _clearAllFood() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Food Items'),
        content: Text('Are you sure you want to remove all food items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _foodItems.clear();
                _totalCalories = 0;
                _totalProtein = 0;
                _totalCarbs = 0;
                _totalFat = 0;
              });
              Navigator.pop(context);
              _animationController.reset();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _foodController.dispose();
    _quantityController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
