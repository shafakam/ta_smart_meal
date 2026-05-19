import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_nutrition_provider.dart';
import '../../../services/notification_service.dart';

class AiForm extends StatefulWidget {
  const AiForm({super.key});

  @override
  State<AiForm> createState() => _AiFormState();
}

class _AiFormState extends State<AiForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _currentWeight = TextEditingController();
  final TextEditingController _targetWeight = TextEditingController();
  final TextEditingController _waterIntake = TextEditingController();
  final TextEditingController _sleepDuration = TextEditingController();

  String _dietType = 'Balanced';
  String _activityLevel = 'Sedentary';
  String _goalType = 'Maintain Weight';
  String _eatingPref = 'Balanced';

  TimeOfDay _breakfastTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 19, minute: 0);

  @override
  void dispose() {
    _budgetController.dispose();
    _caloriesController.dispose();
    _currentWeight.dispose();
    _targetWeight.dispose();
    _waterIntake.dispose();
    _sleepDuration.dispose();
    super.dispose();
  }

  Future<void> _pickTime(String label, TimeOfDay current, ValueChanged<TimeOfDay> onSelected) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) onSelected(picked);
  }

  Widget _buildTimePicker(String label, TimeOfDay timeOfDay, ValueChanged<TimeOfDay> onSelected) {
    return GestureDetector(
      onTap: () => _pickTime(label, timeOfDay, onSelected),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(timeOfDay.format(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Budget per meal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Target calories'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _dietType,
                items: const [
                  DropdownMenuItem(value: 'Balanced', child: Text('Balanced')),
                  DropdownMenuItem(value: 'Vegetarian', child: Text('Vegetarian')),
                  DropdownMenuItem(value: 'Keto', child: Text('Keto')),
                ],
                onChanged: (v) => setState(() => _dietType = v ?? 'Balanced'),
                decoration: const InputDecoration(labelText: 'Diet type'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _activityLevel,
                      items: const [
                        DropdownMenuItem(value: 'Sedentary', child: Text('Sedentary')),
                        DropdownMenuItem(value: 'Lightly Active', child: Text('Lightly Active')),
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(value: 'Very Active', child: Text('Very Active')),
                      ],
                      onChanged: (v) => setState(() => _activityLevel = v ?? 'Sedentary'),
                      decoration: const InputDecoration(labelText: 'Activity level'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _goalType,
                      items: const [
                        DropdownMenuItem(value: 'Weight Loss', child: Text('Weight Loss')),
                        DropdownMenuItem(value: 'Maintain Weight', child: Text('Maintain Weight')),
                        DropdownMenuItem(value: 'Muscle Gain', child: Text('Muscle Gain')),
                      ],
                      onChanged: (v) => setState(() => _goalType = v ?? 'Maintain Weight'),
                      decoration: const InputDecoration(labelText: 'Goal type'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _eatingPref,
                items: const [
                  DropdownMenuItem(value: 'High Protein', child: Text('High Protein')),
                  DropdownMenuItem(value: 'Low Carb', child: Text('Low Carb')),
                  DropdownMenuItem(value: 'Sugar Control', child: Text('Sugar Control')),
                  DropdownMenuItem(value: 'Balanced', child: Text('Balanced')),
                ],
                onChanged: (v) => setState(() => _eatingPref = v ?? 'Balanced'),
                decoration: const InputDecoration(labelText: 'Eating preference'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _currentWeight,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Current weight (kg)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _targetWeight,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Target weight (kg)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _waterIntake,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Daily water intake (L)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sleepDuration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sleep duration (hrs)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTimePicker('Breakfast', _breakfastTime, (value) => setState(() => _breakfastTime = value))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimePicker('Lunch', _lunchTime, (value) => setState(() => _lunchTime = value))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTimePicker('Dinner', _dinnerTime, (value) => setState(() => _dinnerTime = value))),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState == null) return;
                      final provider = Provider.of<AiNutritionProvider>(context, listen: false);
                      final payload = {
                        'budgetPerMeal': double.tryParse(_budgetController.text) ?? 0,
                        'targetCalories': double.tryParse(_caloriesController.text) ?? 2000,
                        'diet': _dietType,
                        'activity': _activityLevel,
                        'goal': _goalType,
                        'eatingPref': _eatingPref,
                        'currentWeight': double.tryParse(_currentWeight.text) ?? 0,
                        'targetWeight': double.tryParse(_targetWeight.text) ?? 0,
                        'waterAvg': double.tryParse(_waterIntake.text) ?? 0,
                        'sleepAvg': double.tryParse(_sleepDuration.text) ?? 0,
                      };
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(const SnackBar(content: Text('Analyzing...')));
                      await provider.analyze(payload);
                      await NotificationService.instance.scheduleMealReminders(
                        breakfastHour: _breakfastTime.hour,
                        breakfastMinute: _breakfastTime.minute,
                        lunchHour: _lunchTime.hour,
                        lunchMinute: _lunchTime.minute,
                        dinnerHour: _dinnerTime.hour,
                        dinnerMinute: _dinnerTime.minute,
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(const SnackBar(content: Text('AI analysis updated and reminders scheduled')));
                    },
                    child: const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      _formKey.currentState?.reset();
                    },
                    child: const Text('Reset'),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
