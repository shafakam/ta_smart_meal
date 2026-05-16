import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final Random _random = Random();
  final List<_FallingFood> _foods = [];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _gameTimer;

  double _basketX = 0.5;
  int _score = 0;
  int _bestScore = 0;
  int _timeLeft = 45;
  int _tick = 0;
  bool _isRunning = false;
  String _playerName = 'Kamu';
  List<_ScoreRow> _scoreHistory = [];

  static const List<_FoodTemplate> _healthyFoods = [
    _FoodTemplate(Icons.eco, 'Sayur', true),
    _FoodTemplate(Icons.restaurant, 'Protein', true),
    _FoodTemplate(Icons.local_drink, 'Air putih', true),
  ];

  static const List<_FoodTemplate> _unhealthyFoods = [
    _FoodTemplate(Icons.fastfood, 'Fast food', false),
    _FoodTemplate(Icons.local_pizza, 'Pizza', false),
    _FoodTemplate(Icons.icecream, 'Dessert', false),
  ];

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _loadPlayerName();
    _startAccelerometer();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString('smartbite_catch_leaderboard');
    final history = _decodeScoreRows(rawHistory);
    if (!mounted) return;
    setState(() {
      _bestScore = prefs.getInt('smartbite_catch_best_score') ?? 0;
      _scoreHistory = history;
    });
  }

  Future<void> _loadPlayerName() async {
    try {
      final userId = await AuthService().getUserId();
      if (userId == null) return;
      final db = await DatabaseService().database;
      final result =
          await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (result.isEmpty || !mounted) return;
      setState(() {
        _playerName = result.first['username']?.toString() ?? 'Kamu';
      });
    } catch (_) {}
  }

  Future<void> _saveBestScore() async {
    if (_score <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final history = [
      _ScoreRow(_playerName, _score, DateTime.now()),
      ..._scoreHistory,
    ]..sort((a, b) => b.score.compareTo(a.score));
    final trimmedHistory = history.take(10).toList();
    if (_score > _bestScore) {
      await prefs.setInt('smartbite_catch_best_score', _score);
    }
    await prefs.setString(
      'smartbite_catch_leaderboard',
      _encodeScoreRows(trimmedHistory),
    );
    if (!mounted) return;
    setState(() {
      if (_score > _bestScore) {
        _bestScore = _score;
      }
      _scoreHistory = trimmedHistory;
    });
  }

  void _startAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (!_isRunning || !mounted) return;
      setState(() {
        _basketX = (_basketX - event.x * 0.018).clamp(0.08, 0.92);
      });
    });
  }

  void _startGame() {
    _gameTimer?.cancel();
    setState(() {
      _foods.clear();
      _basketX = 0.5;
      _score = 0;
      _timeLeft = 45;
      _tick = 0;
      _isRunning = true;
    });

    _gameTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) return;
      setState(() {
        _tick++;
        if (_tick % 10 == 0) {
          _spawnFood();
        }
        if (_tick % 13 == 0) {
          _timeLeft--;
        }

        for (final food in _foods) {
          food.y += food.speed;
        }

        _handleCollisions();
        _foods.removeWhere((food) {
          if (food.y > 1.08) {
            if (food.isHealthy) {
              _score = max(0, _score - 3);
            }
            return true;
          }
          return false;
        });

        if (_timeLeft <= 0) {
          _finishGame();
        }
      });
    });
  }

  void _finishGame() {
    _gameTimer?.cancel();
    _isRunning = false;
    _saveBestScore();
  }

  void _spawnFood() {
    final useHealthy = _random.nextDouble() > 0.35;
    final pool = useHealthy ? _healthyFoods : _unhealthyFoods;
    final template = pool[_random.nextInt(pool.length)];
    _foods.add(
      _FallingFood(
        x: 0.12 + _random.nextDouble() * 0.76,
        y: -0.08,
        speed: 0.012 + _random.nextDouble() * 0.012,
        icon: template.icon,
        label: template.label,
        isHealthy: template.isHealthy,
      ),
    );
  }

  void _handleCollisions() {
    final caught = <_FallingFood>[];
    for (final food in _foods) {
      final isInCatchZone = food.y >= 0.76 && food.y <= 0.92;
      final isNearBasket = (food.x - _basketX).abs() < 0.13;
      if (isInCatchZone && isNearBasket) {
        _score = max(0, _score + (food.isHealthy ? 10 : -8));
        caught.add(food);
      }
    }
    _foods.removeWhere(caught.contains);
  }

  void _moveBasketByDrag(DragUpdateDetails details, double width) {
    if (!_isRunning || width <= 0) return;
    setState(() {
      _basketX = (_basketX + details.delta.dx / width).clamp(0.08, 0.92);
    });
  }

  List<_ScoreRow> get _leaderboard {
    final rows = [
      if (_score > 0) _ScoreRow(_playerName, _score, DateTime.now()),
      ..._scoreHistory,
    ]..sort((a, b) => b.score.compareTo(a.score));
    return rows.take(5).toList();
  }

  String _encodeScoreRows(List<_ScoreRow> rows) {
    return rows
        .map((row) =>
            '${row.name}|${row.score}|${row.playedAt.toIso8601String()}')
        .join('\n');
  }

  List<_ScoreRow> _decodeScoreRows(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split('\n')
        .map((line) {
          final parts = line.split('|');
          if (parts.length < 3) return null;
          return _ScoreRow(
            parts[0],
            int.tryParse(parts[1]) ?? 0,
            DateTime.tryParse(parts[2]) ?? DateTime.now(),
          );
        })
        .whereType<_ScoreRow>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildGameBoard(),
              const SizedBox(height: 18),
              _buildStats(),
              const SizedBox(height: 18),
              _buildLeaderboard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF19A974), Color(0xFF1D7DD8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF159A85).withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/smartbite_logo.png',
              width: 66,
              height: 66,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartBite Catch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Miringkan HP ke kiri atau kanan untuk menangkap makanan sehat.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final boardHeight = min(width * 1.38, 560.0);
        return GestureDetector(
          onHorizontalDragUpdate: (details) =>
              _moveBasketByDrag(details, width),
          child: Container(
            height: boardHeight,
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE3EEE7)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BoardPainter(),
                  ),
                ),
                ..._foods.map(
                  (food) => Positioned(
                    left: food.x * width - 25,
                    top: food.y * boardHeight,
                    child: _FoodBubble(food: food),
                  ),
                ),
                Positioned(
                  left: _basketX * width - 45,
                  bottom: 22,
                  child: const _Basket(),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: _ScoreChip(
                    icon: Icons.star_rounded,
                    label: 'Score',
                    value: '$_score',
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: _ScoreChip(
                    icon: Icons.timer_rounded,
                    label: 'Time',
                    value: '${max(0, _timeLeft)}s',
                  ),
                ),
                if (!_isRunning)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.82),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _score > 0
                                ? Icons.emoji_events
                                : Icons.sports_esports,
                            size: 58,
                            color: const Color(0xFF4BAE5F),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _score > 0 ? 'Skor kamu $_score' : 'Siap main?',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tangkap yang sehat, hindari junk food.',
                            style: TextStyle(color: Color(0xFF7E8B84)),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _startGame,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label:
                                Text(_score > 0 ? 'Main Lagi' : 'Mulai Game'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4BAE5F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Best Score',
            value: '$_bestScore',
            color: const Color(0xFFFFA726),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _StatCard(
            icon: Icons.favorite_rounded,
            label: 'Healthy Food',
            value: '+10',
            color: Color(0xFF4BAE5F),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _StatCard(
            icon: Icons.warning_rounded,
            label: 'Junk Food',
            value: '-8',
            color: Color(0xFFE85D75),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: Color(0xFF4BAE5F)),
              SizedBox(width: 10),
              Text(
                'Ranking Lokal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._leaderboard.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final row = entry.value;
            final isUser = row.name == _playerName;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isUser ? const Color(0xFFEAF7ED) : const Color(0xFFF8FAF8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#$rank',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.name,
                      style: TextStyle(
                        fontWeight: isUser ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${row.score} pts',
                    style: const TextStyle(
                      color: Color(0xFF4BAE5F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FoodBubble extends StatelessWidget {
  const _FoodBubble({required this.food});

  final _FallingFood food;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color:
            food.isHealthy ? const Color(0xFFEAF7ED) : const Color(0xFFFFEDF1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        food.icon,
        color:
            food.isHealthy ? const Color(0xFF4BAE5F) : const Color(0xFFE85D75),
        size: 28,
      ),
    );
  }
}

class _Basket extends StatelessWidget {
  const _Basket();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF4BAE5F),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4BAE5F).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: const Icon(
        Icons.shopping_basket_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4BAE5F), size: 20),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF7E8B84)),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8B84)),
          ),
        ],
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEAF7ED)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FallingFood {
  _FallingFood({
    required this.x,
    required this.y,
    required this.speed,
    required this.icon,
    required this.label,
    required this.isHealthy,
  });

  final double x;
  double y;
  final double speed;
  final IconData icon;
  final String label;
  final bool isHealthy;
}

class _FoodTemplate {
  const _FoodTemplate(this.icon, this.label, this.isHealthy);

  final IconData icon;
  final String label;
  final bool isHealthy;
}

class _ScoreRow {
  const _ScoreRow(this.name, this.score, this.playedAt);

  final String name;
  final int score;
  final DateTime playedAt;
}
