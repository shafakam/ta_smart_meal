import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class BudgetProvider with ChangeNotifier {
  double _weeklyLimit = 0.0;
  double _spent = 0.0;
  List<Expense> _recentExpenses = [];
  bool _isLoading = false;
  String? _errorMessage;

  double get weeklyLimit => _weeklyLimit;
  double get spent => _spent;
  double get remaining => _weeklyLimit - _spent;
  double get progress =>
      (_weeklyLimit > 0) ? (_spent / _weeklyLimit).clamp(0.0, 1.0) : 0.0;
  List<Expense> get recentExpenses => _recentExpenses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 1. FUNGSI LOAD DATA
  Future<void> loadData(int userId) async {
    _isLoading = true;
    try {
      final budgets = await DatabaseService().getBudgetsByUserId(userId);
      if (budgets.isNotEmpty) {
        _weeklyLimit = budgets.first.weeklyLimit;
        _spent = budgets.first.spent;
      } else {
        _weeklyLimit = 0.0;
        _spent = 0.0;
      }
      _recentExpenses = await DatabaseService().getExpensesByUserId(userId);
      await NotificationService.instance.showBudgetWarning(
        userId: userId,
        weeklyLimit: _weeklyLimit,
        spent: _spent,
      );
    } catch (e) {
      debugPrint("Error Load: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. FUNGSI TAMBAH
  Future<bool> addExpense(Expense exp, int userId, bool addToBudget) async {
    try {
      _errorMessage = null;
      if (addToBudget && !_canAddWeeklyExpense(exp.price)) {
        _setBudgetLimitError();
        return false;
      }
      if (addToBudget) exp.isWeekly = 1;
      await DatabaseService().insertExpense(exp);
      if (addToBudget) {
        _spent += exp.price;
        _recentExpenses.insert(0, exp);
        notifyListeners();
        await _updateDBBudget(userId);
      }
      await loadData(userId);
      return true;
    } catch (e) {
      debugPrint("Error Add Expense: $e");
      _errorMessage = 'Gagal menambahkan pengeluaran.';
      notifyListeners();
      return false;
    }
  }

  // 3. FUNGSI UPDATE / EDIT (INI YANG TADI HILANG)
  Future<bool> updateExpense(Expense exp, int userId) async {
    try {
      _errorMessage = null;
      // Ambil data lama sebelum diupdate untuk hitung selisih harga
      final oldExpense = _recentExpenses.firstWhere((e) => e.id == exp.id);

      if (oldExpense.isWeekly == 1) {
        final nextSpent = _spent - oldExpense.price + exp.price;
        if (!_isWithinWeeklyLimit(nextSpent)) {
          _setBudgetLimitError();
          return false;
        }
      }

      await DatabaseService().updateExpense(exp);

      // Jika barang ini ada di list mingguan, update total pengeluaran (spent)
      if (oldExpense.isWeekly == 1) {
        _spent = _spent - oldExpense.price + exp.price;
        final index =
            _recentExpenses.indexWhere((expense) => expense.id == exp.id);
        if (index >= 0) {
          _recentExpenses[index] = exp..isWeekly = oldExpense.isWeekly;
        }
        notifyListeners();
        await _updateDBBudget(userId);
      }

      await loadData(userId);
      return true;
    } catch (e) {
      debugPrint("Error Update Expense: $e");
      _errorMessage = 'Gagal mengubah pengeluaran.';
      notifyListeners();
      return false;
    }
  }

  // 4. FUNGSI HAPUS
  Future<void> deleteExpense(int id, int userId) async {
    try {
      final item = _recentExpenses.firstWhere((e) => e.id == id);
      if (item.isWeekly == 1) {
        _spent -= item.price;
        _recentExpenses.removeWhere((expense) => expense.id == id);
        notifyListeners();
        await _updateDBBudget(userId);
      }
      await DatabaseService().deleteExpense(id);
      await loadData(userId);
    } catch (e) {
      debugPrint("Error Delete: $e");
    }
  }

  // 5. FUNGSI LIMIT BUDGET
  Future<void> updateWeeklyLimit(double newLimit, int userId) async {
    try {
      _weeklyLimit = newLimit;
      notifyListeners();
      await _updateDBBudget(userId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error Update Limit: $e");
    }
  }

  // 6. FUNGSI PINDAH STATUS MINGGUAN
  Future<bool> addToWeeklyList(int expenseId, double price, int userId) async {
    _errorMessage = null;
    if (!_canAddWeeklyExpense(price)) {
      _setBudgetLimitError();
      return false;
    }
    await DatabaseService().updateExpenseStatus(expenseId, 1);
    _spent += price;
    final index =
        _recentExpenses.indexWhere((expense) => expense.id == expenseId);
    if (index >= 0) _recentExpenses[index].isWeekly = 1;
    notifyListeners();
    await _updateDBBudget(userId);
    await loadData(userId);
    return true;
  }

  Future<void> removeFromWeeklyList(
      int expenseId, double price, int userId) async {
    await DatabaseService().updateExpenseStatus(expenseId, 0);
    _spent -= price;
    final index =
        _recentExpenses.indexWhere((expense) => expense.id == expenseId);
    if (index >= 0) _recentExpenses[index].isWeekly = 0;
    notifyListeners();
    await _updateDBBudget(userId);
    await loadData(userId);
  }

  // 7. HELPER SYNC DATABASE
  Future<void> _updateDBBudget(int userId) async {
    await DatabaseService().insertBudget(Budget(
        id: 1,
        weeklyLimit: _weeklyLimit,
        spent: _spent,
        remaining: _weeklyLimit - _spent,
        userId: userId));
    await NotificationService.instance.showBudgetWarning(
      userId: userId,
      weeklyLimit: _weeklyLimit,
      spent: _spent,
    );
  }

  // 8. HITUNG KATEGORI
  double getWeeklyTotalByCategory(String category) {
    return _recentExpenses
        .where((e) => e.category == category && e.isWeekly == 1)
        .fold(0.0, (sum, item) => sum + item.price);
  }

  bool _canAddWeeklyExpense(double price) {
    return _weeklyLimit > 0 &&
        remaining > 0 &&
        _isWithinWeeklyLimit(_spent + price);
  }

  bool _isWithinWeeklyLimit(double value) {
    return _weeklyLimit > 0 && value <= _weeklyLimit;
  }

  void _setBudgetLimitError() {
    _errorMessage =
        'Pengeluaran tidak bisa ditambahkan karena sisa budget sudah habis atau tidak cukup.';
    notifyListeners();
  }
}
