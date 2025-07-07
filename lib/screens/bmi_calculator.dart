import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../drawer/app_drawer.dart';

class BMICalculator extends StatefulWidget {
  @override
  _BMICalculatorState createState() => _BMICalculatorState();
}

class _BMICalculatorState extends State<BMICalculator> with TickerProviderStateMixin {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double? _bmi;
  String _bmiCategory = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isMetric = true; // true for metric (cm/kg), false for imperial (ft/lbs)

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'BMI Calculator',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: const Color(0xFF2E3192),
        foregroundColor: const Color(0xFF00E5FF),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: const Color(0xFF00E5FF)),
            onPressed: _clearFields,
            tooltip: 'Clear All',
          ),
        ],
      ),
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Card(
                  elevation: 8,
                  color: Colors.white.withOpacity(0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'CALCULATE YOUR BMI',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2E3192),
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20),
                          
                          // Unit Toggle
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2E3192),
                                  Color(0xFF1BFFFF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: EdgeInsets.all(2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isMetric = true),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: _isMetric ? const LinearGradient(
                                            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                                          ) : null,
                                          borderRadius: BorderRadius.circular(23),
                                        ),
                                        child: Text(
                                          'Metric',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _isMetric ? Colors.white : const Color(0xFF2E3192),
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isMetric = false),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: !_isMetric ? const LinearGradient(
                                            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                                          ) : null,
                                          borderRadius: BorderRadius.circular(23),
                                        ),
                                        child: Text(
                                          'Imperial',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: !_isMetric ? Colors.white : const Color(0xFF2E3192),
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 24),
                          
                          TextFormField(
                            controller: _heightController,
                            decoration: InputDecoration(
                              labelText: _isMetric ? 'Height (cm)' : 'Height (ft)',
                              labelStyle: TextStyle(color: const Color(0xFF2E3192)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: const Color(0xFF2E3192)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: const Color(0xFF00E5FF), width: 2),
                              ),
                              prefixIcon: Icon(Icons.height, color: const Color(0xFF2E3192)),
                              suffixText: _isMetric ? 'cm' : 'ft',
                              suffixStyle: TextStyle(color: const Color(0xFF2E3192)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your height';
                              }
                              double? height = double.tryParse(value);
                              if (height == null || height <= 0) {
                                return 'Please enter a valid height';
                              }
                              if (_isMetric && (height < 50 || height > 300)) {
                                return 'Height should be between 50-300 cm';
                              }
                              if (!_isMetric && (height < 1.5 || height > 9)) {
                                return 'Height should be between 1.5-9 ft';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 20),
                          
                          TextFormField(
                            controller: _weightController,
                            decoration: InputDecoration(
                              labelText: _isMetric ? 'Weight (kg)' : 'Weight (lbs)',
                              labelStyle: TextStyle(color: const Color(0xFF2E3192)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: const Color(0xFF2E3192)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: const Color(0xFF00E5FF), width: 2),
                              ),
                              prefixIcon: Icon(Icons.monitor_weight, color: const Color(0xFF2E3192)),
                              suffixText: _isMetric ? 'kg' : 'lbs',
                              suffixStyle: TextStyle(color: const Color(0xFF2E3192)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your weight';
                              }
                              double? weight = double.tryParse(value);
                              if (weight == null || weight <= 0) {
                                return 'Please enter a valid weight';
                              }
                              if (_isMetric && (weight < 10 || weight > 500)) {
                                return 'Weight should be between 10-500 kg';
                              }
                              if (!_isMetric && (weight < 20 || weight > 1100)) {
                                return 'Weight should be between 20-1100 lbs';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 24),
                          
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2E3192),
                                  Color(0xFF1BFFFF),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _calculateBMI,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                'CALCULATE BMI',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                if (_bmi != null) ...[
                  SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Card(
                      elevation: 8,
                      color: Colors.white.withOpacity(0.95),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                'YOUR BMI RESULT',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF2E3192),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 20),
                              Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF2E3192).withOpacity(0.1),
                                      const Color(0xFF1BFFFF).withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: const Color(0xFF00E5FF),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _bmi!.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: _getCategoryColor(),
                                      ),
                                    ),
                                    Text(
                                      'BMI',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: const Color(0xFF2E3192),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _getCategoryColor().withOpacity(0.2),
                                      _getCategoryColor().withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(color: _getCategoryColor(), width: 2),
                                ),
                                child: Text(
                                  _bmiCategory.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _getCategoryColor(),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                _getHealthAdvice(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF2E3192),
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // BMI Scale Visual
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Card(
                      elevation: 8,
                      color: Colors.white.withOpacity(0.95),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BMI SCALE',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF2E3192),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 16),
                              _buildBMIScaleItem('Underweight', '< 18.5', Colors.blue),
                              _buildBMIScaleItem('Normal weight', '18.5 - 24.9', Colors.green),
                              _buildBMIScaleItem('Overweight', '25.0 - 29.9', Colors.orange),
                              _buildBMIScaleItem('Obese', '≥ 30.0', Colors.red),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBMIScaleItem(String category, String range, Color color) {
    bool isCurrentCategory = _bmiCategory == category;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: isCurrentCategory ? LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ) : null,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentCategory ? Border.all(color: color, width: 2) : Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              category,
              style: TextStyle(
                fontWeight: isCurrentCategory ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF2E3192),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            range,
            style: TextStyle(
              color: const Color(0xFF2E3192).withOpacity(0.7),
              fontSize: 12,
              fontWeight: isCurrentCategory ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _calculateBMI() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    double height = double.parse(_heightController.text);
    double weight = double.parse(_weightController.text);

    // Convert imperial to metric if needed
    if (!_isMetric) {
      height = height * 30.48; // feet to cm
      weight = weight * 0.453592; // lbs to kg
    }

    double heightInMeters = height / 100;
    double bmi = weight / (heightInMeters * heightInMeters);

    setState(() {
      _bmi = bmi;
      _bmiCategory = _getBMICategory(bmi);
    });

    _animationController.reset();
    _animationController.forward();

    // Hide keyboard
    FocusScope.of(context).unfocus();
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _getCategoryColor() {
    if (_bmi! < 18.5) return Colors.blue;
    if (_bmi! < 25) return Colors.green;
    if (_bmi! < 30) return Colors.orange;
    return Colors.red;
  }

  String _getHealthAdvice() {
    if (_bmi! < 18.5) {
      return 'Consider consulting a healthcare provider about healthy weight gain strategies.';
    } else if (_bmi! < 25) {
      return 'Great! You\'re in the healthy weight range. Keep up the good work!';
    } else if (_bmi! < 30) {
      return 'Consider adopting a healthy diet and regular exercise routine.';
    } else {
      return 'It\'s recommended to consult with a healthcare professional for personalized advice.';
    }
  }

  void _clearFields() {
    _heightController.clear();
    _weightController.clear();
    setState(() {
      _bmi = null;
      _bmiCategory = '';
    });
    _animationController.reset();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}