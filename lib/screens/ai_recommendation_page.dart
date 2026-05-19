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
      _restoreNutritionState();
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

  Future<void> _restoreNutritionState() async {
    final provider = context.read<RecommendationProvider>();
    final savedProfile = await provider.loadPersistedState();
    if (!mounted) return;
    if (savedProfile != null) {
      setState(() {
        _budget = savedProfile.budget;
        _calories = savedProfile.targetCalories;
        _dietType = savedProfile.dietType;
        _activityLevel = savedProfile.activityLevel;
        _goalType = savedProfile.goalType;
        _eatingPreference = savedProfile.eatingPreference;
        _currentWeightCtrl.text = _formatNumber(savedProfile.currentWeight);
        _targetWeightCtrl.text = _formatNumber(savedProfile.targetWeight);
        _waterCtrl.text = _formatNumber(savedProfile.dailyWaterIntake);
        _sleepCtrl.text = _formatNumber(savedProfile.sleepDuration);
      });
    } else {
      provider.refreshInsight(_profile);
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

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
              (value) => _updateProfile(provider, () => _budget = value)),
          _slider('Target calories', _calories, 1500, false,
              (value) => _updateProfile(provider, () => _calories = value)),
          _dropdown(
              'Diet type', _dietType, ['Balanced', 'Vegan', 'Keto', 'Low Carb'],
              (value) {
            _updateProfile(provider, () => _dietType = value);
          }),
          _dropdown('Activity level', _activityLevel, [
            'Sedentary',
            'Lightly Active',
            'Active',
            'Very Active'
          ], (value) {
            _updateProfile(provider, () => _activityLevel = value);
          }),
          _dropdown('Goal type', _goalType,
              ['Weight Loss', 'Maintain Weight', 'Muscle Gain'], (value) {
            _updateProfile(provider, () => _goalType = value);
          }),
          _dropdown('Eating preference', _eatingPreference, [
            'High Protein',
            'Low Carb',
            'Sugar Control',
            'Balanced'
          ], (value) {
            _updateProfile(provider, () => _eatingPreference = value);
          }),
          Row(
            children: [
              Expanded(
                child: _numberField(
                    'Current weight', _currentWeightCtrl, 'kg', provider),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                    'Target weight', _targetWeightCtrl, 'kg', provider),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child:
                      _numberField('Water intake', _waterCtrl, 'L', provider)),
              const SizedBox(width: 10),
              Expanded(
                  child: _numberField('Sleep', _sleepCtrl, 'hours', provider)),
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

  void _updateProfile(RecommendationProvider provider, VoidCallback update) {
    setState(update);
    provider.refreshInsight(_profile);
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showChatAssistant,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF31CFA3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Nutrition Chat',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Tanya kalori, pola makan, berat badan, atau meal plan.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_up_rounded),
          ],
        ),
      ),
    );
  }

  void _showChatAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Consumer<RecommendationProvider>(
              builder: (context, provider, _) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 5,
                        margin: const EdgeInsets.only(top: 12, bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('AI Nutrition Assistant',
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 4),
                                  Text(
                                    'Ask about calories, habits, budget meals & goals',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 26),
                      Expanded(
                        child: provider.chatHistory.isEmpty
                            ? ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.all(24),
                                children: const [
                                  SizedBox(height: 90),
                                  CircleAvatar(
                                    radius: 46,
                                    backgroundColor: Color(0xFF31CFA3),
                                    child: Icon(Icons.chat_bubble_outline,
                                        color: Colors.white, size: 42),
                                  ),
                                  SizedBox(height: 24),
                                  Text(
                                    'Ask me anything about your nutrition',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Get personal advice based on your saved meals, activity, weight goal, sleep, water intake, and weekly pattern.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey, height: 1.45),
                                  ),
                                ],
                              )
                            : ListView(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(18, 4, 18, 18),
                                children: provider.chatHistory
                                    .map((message) => Align(
                                          alignment: message.role == 'user'
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            padding: const EdgeInsets.all(13),
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.76,
                                            ),
                                            decoration: BoxDecoration(
                                              color: message.role == 'user'
                                                  ? const Color(0xFF31CFA3)
                                                  : const Color(0xFFF1F6F8),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            child: Text(
                                              message.text,
                                              style: TextStyle(
                                                color: message.role == 'user'
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                      ),
                      if (provider.isChatLoading)
                        const LinearProgressIndicator(minHeight: 2),
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: EdgeInsets.only(
                            left: 18,
                            right: 18,
                            top: 12,
                            bottom:
                                12 + MediaQuery.of(context).viewInsets.bottom,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _chatCtrl,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: 'Ask about your meals...',
                                    filled: true,
                                    fillColor: const Color(0xFFF2F8FA),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: FloatingActionButton(
                                  heroTag: 'nutrition-chat-send',
                                  elevation: 0,
                                  backgroundColor: const Color(0xFF31CFA3),
                                  onPressed: provider.isChatLoading
                                      ? null
                                      : () {
                                          final text = _chatCtrl.text.trim();
                                          if (text.isEmpty) return;
                                          _chatCtrl.clear();
                                          provider.askAssistant(
                                              profile: _profile,
                                              question: text);
                                        },
                                  child: const Icon(Icons.send_rounded,
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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

  Widget _numberField(String label, TextEditingController controller,
      String suffix, RecommendationProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => provider.refreshInsight(_profile),
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
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.asMap().entries.map((entry) {
          final height = 18 + (entry.value / maxValue) * 58;
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
