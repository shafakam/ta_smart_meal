import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/meal.dart';
import '../models/nutrition_insight.dart';
import '../models/nutrition_profile.dart';
import '../providers/recommendation_providers.dart';

class SaranMenuPage extends StatefulWidget {
  const SaranMenuPage({super.key});

  @override
  State<SaranMenuPage> createState() => _SaranMenuPageState();
}

class _SaranMenuPageState extends State<SaranMenuPage> {
  double _budget = 50000;
  double _calories = 600;
  String _dietType = 'Balanced';
  String _activityLevel = 'Lightly Active';
  String _goalType = 'Maintain Weight';
  String _eatingPreference = 'Balanced';
  final _currentWeightCtrl = TextEditingController(text: '60');
  final _targetWeightCtrl = TextEditingController(text: '58');
  final _waterCtrl = TextEditingController(text: '2');
  final _sleepCtrl = TextEditingController(text: '7');
  final _chatCtrl = TextEditingController();
  final String _currentCurrency = 'IDR';
  double _exchangeRate = 1.0;

  NumberFormat get _formatter => NumberFormat.currency(
        locale: _currentCurrency == 'IDR' ? 'id_ID' : 'en_US',
        symbol: _currentCurrency == 'IDR'
            ? 'Rp '
            : (_currentCurrency == 'USD' ? '\$ ' : 'EUR '),
        decimalDigits: _currentCurrency == 'IDR' ? 0 : 2,
      );

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecommendationProvider>().refreshInsight(_profile);
    });
  }

  @override
  void dispose() {
    _currentWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _waterCtrl.dispose();
    _sleepCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  NutritionProfile get _profile => NutritionProfile(
        budget: _budget,
        targetCalories: _calories,
        dietType: _dietType,
        activityLevel: _activityLevel,
        goalType: _goalType,
        eatingPreference: _eatingPreference,
        currentWeight: double.tryParse(_currentWeightCtrl.text) ?? 60,
        targetWeight: double.tryParse(_targetWeightCtrl.text) ?? 58,
        dailyWaterIntake: double.tryParse(_waterCtrl.text) ?? 2,
        sleepDuration: double.tryParse(_sleepCtrl.text) ?? 7,
      );

  Future<void> _loadCurrency() async {
    final apiKey = dotenv.get('CURRENCY_API_KEY', fallback: '');
    var rate = 1.0;
    try {
      if (_currentCurrency != 'IDR' && apiKey.isNotEmpty) {
        final url = Uri.parse(
            'https://v6.exchangerate-api.com/v6/$apiKey/pair/IDR/$_currentCurrency');
        final response =
            await http.get(url).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          rate =
              (json.decode(response.body)['conversion_rate'] as num).toDouble();
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _exchangeRate = rate);
  }

  String _money(double value) => _formatter.format(value * _exchangeRate);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecommendationProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      body: RefreshIndicator(
        onRefresh: () => provider.refreshInsight(_profile),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputCard(provider),
                  const SizedBox(height: 16),
                  _buildInsightCard(provider.insight),
                  const SizedBox(height: 16),
                  _sectionTitle('Smart Recommendations'),
                  const SizedBox(height: 10),
                  if (provider.isLoading)
                    const _SkeletonList()
                  else if (provider.recommendedMeals.isEmpty)
                    _emptyState(provider.errorMessage)
                  else
                    ...provider.recommendedMeals.map(_buildMealCard),
                  const SizedBox(height: 16),
                  _buildDailyPlan(provider),
                  const SizedBox(height: 16),
                  _buildChatbot(provider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00A878), Color(0xFF087CA7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Nutrition Assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Personalized recommendations powered by your eating habits and goals',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(RecommendationProvider provider) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Nutrition Profile'),
          _slider('Budget per meal', _budget, 100000, true,
              (value) => setState(() => _budget = value)),
          _slider('Target calories', _calories, 1500, false,
              (value) => setState(() => _calories = value)),
          _dropdown(
              'Diet type', _dietType, ['Balanced', 'Vegan', 'Keto', 'Low Carb'],
              (value) {
            setState(() => _dietType = value);
          }),
          _dropdown('Activity level', _activityLevel, [
            'Sedentary',
            'Lightly Active',
            'Active',
            'Very Active'
          ], (value) {
            setState(() => _activityLevel = value);
          }),
          _dropdown('Goal type', _goalType,
              ['Weight Loss', 'Maintain Weight', 'Muscle Gain'], (value) {
            setState(() => _goalType = value);
          }),
          _dropdown('Eating preference', _eatingPreference, [
            'High Protein',
            'Low Carb',
            'Sugar Control',
            'Balanced'
          ], (value) {
            setState(() => _eatingPreference = value);
          }),
          Row(
            children: [
              Expanded(
                child: _numberField('Current weight', _currentWeightCtrl, 'kg'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField('Target weight', _targetWeightCtrl, 'kg'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: _numberField('Water intake', _waterCtrl, 'L')),
              const SizedBox(width: 10),
              Expanded(child: _numberField('Sleep', _sleepCtrl, 'hours')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: provider.isLoading
                  ? null
                  : () => provider.fetchRecommendations(profile: _profile),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate AI Nutrition Plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(NutritionInsight? insight) {
    if (insight == null) {
      return const _Panel(
        child: Text('Insight akan muncul setelah data profil dianalisis.'),
      );
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('AI Weekly Insight'),
          const SizedBox(height: 10),
          Text(insight.summary, style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                    'Avg kcal', insight.averageCalories.round().toString()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  insight.calorieDelta >= 0 ? 'Surplus' : 'Defisit',
                  '${insight.calorieDelta.abs().round()}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric('Predict',
                    '${insight.predictedWeightChange.toStringAsFixed(2)} kg'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MiniBarChart(values: insight.dailyCalories),
          const SizedBox(height: 14),
          Text('Sering dikonsumsi: ${insight.mostFrequentFood}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...insight.habitWarnings
              .map((item) => _chipLine(Icons.warning_amber, item)),
          ...insight.recommendations
              .map((item) => _chipLine(Icons.check_circle_outline, item)),
        ],
      ),
    );
  }

  Widget _buildMealCard(Meal meal) {
    return _Panel(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              _mealThumb(meal.imageUrl, 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(meal.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('${meal.matchPercentage}%',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('${meal.calories} kcal')),
              Text(_money(meal.price),
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          if (meal.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Alasan: ${meal.reason}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRecipe(meal),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Resep'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await context.read<RecommendationProvider>().saveMeal(meal);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${meal.name} disimpan.')),
                    );
                  },
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyPlan(RecommendationProvider provider) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Smart Daily Plan'),
          const SizedBox(height: 10),
          if (provider.weeklyPlan.isEmpty)
            const Text('Generate dulu untuk membuat rencana pagi, siang, sore.')
          else
            ...provider.weeklyPlan.map(_dailyRow),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.weeklyPlan.isEmpty
                  ? null
                  : () async {
                      final added = await provider.applyDailyPlan();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(added == 0
                              ? 'Tidak ada hari kosong.'
                              : 'Paket 1 hari masuk ke Planner.'),
                        ),
                      );
                    },
              child: const Text('Apply 1 Hari ke Planner'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatbot(RecommendationProvider provider) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Chatbot Nutrition Assistant'),
          const SizedBox(height: 10),
          if (provider.chatHistory.isEmpty)
            const Text('Tanyakan: "Kenapa berat badanku belum turun?"',
                style: TextStyle(color: Colors.grey)),
          ...provider.chatHistory.map((message) => Align(
                alignment: message.role == 'user'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: message.role == 'user'
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(message.text),
                ),
              )),
          if (provider.isChatLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Tanya pola makanmu...',
                  ),
                ),
              ),
              IconButton(
                onPressed: provider.isChatLoading
                    ? null
                    : () {
                        final text = _chatCtrl.text;
                        _chatCtrl.clear();
                        provider.askAssistant(
                            profile: _profile, question: text);
                      },
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dailyRow(Meal meal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_mealTimeLabel(meal.mealTime),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(meal.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(_money(meal.price),
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double max, bool money,
      ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label, style: const TextStyle(color: Colors.grey))),
            Text(money ? _money(value) : '${value.round()} cal',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(value: value, min: 0, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }

  Widget _numberField(
      String label, TextEditingController controller, String suffix) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _chipLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _mealThumb(String url, double size) {
    final safeUrl =
        url.trim().isEmpty || url.contains('example.com') ? '' : url;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.restaurant_menu, color: Colors.green.shade700),
    );
    if (safeUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        safeUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _emptyState(String? error) {
    return _Panel(
      child: Text(
        error ?? 'Belum ada rekomendasi. Isi profile lalu generate.',
        style: TextStyle(color: error == null ? Colors.grey : Colors.redAccent),
      ),
    );
  }

  String _mealTimeLabel(String mealTime) {
    final lower = mealTime.toLowerCase();
    if (lower.contains('breakfast') || lower.contains('pagi')) return 'Pagi';
    if (lower.contains('dinner') ||
        lower.contains('malam') ||
        lower.contains('sore')) {
      return 'Sore';
    }
    return 'Siang';
  }

  void _showRecipe(Meal meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(22),
          children: [
            Text(meal.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(meal.description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 18),
            const Text('Bahan', style: TextStyle(fontWeight: FontWeight.bold)),
            ...meal.ingredients.map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline, size: 18),
                  title: Text(item),
                )),
            const SizedBox(height: 12),
            const Text('Cara Masak',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...meal.steps.asMap().entries.map((entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 12,
                    child: Text('${entry.key + 1}',
                        style: const TextStyle(fontSize: 11)),
                  ),
                  title: Text(entry.value),
                )),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _Panel({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<int> values;
  const _MiniBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b).clamp(1, 10000);
    return SizedBox(
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.asMap().entries.map((entry) {
          final height = 20 + (entry.value / maxValue) * 60;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${entry.key + 1}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 92,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
