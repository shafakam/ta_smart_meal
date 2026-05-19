const DEFAULT_MEALS = [
  { name: 'Nasi merah ayam panggang', calories: 520, price: 25, protein: 30, sugar: 5 },
  { name: 'Salad quinoa sayuran', calories: 420, price: 28, protein: 15, sugar: 6 },
  { name: 'Oatmeal buah dan kacang', calories: 330, price: 18, protein: 12, sugar: 8 },
  { name: 'Sup ikan dan sayur', calories: 460, price: 22, protein: 28, sugar: 3 },
  { name: 'Sandwich ayam gandum', calories: 390, price: 20, protein: 26, sugar: 4 },
];

// Simple recommender that scores candidate meals against user profile
function recommendMeals(userProfile, candidates) {
  // userProfile: {budgetPerMeal, targetCalories, activity, goal, eatingPref, topFoods}
  const { budgetPerMeal=9999, targetCalories=2000, topFoods=[] } = userProfile || {};

  function score(candidate) {
    let s = 0;
    // calories match: closer to target gives higher score (prefers slightly under target)
    const calorieDiff = Math.abs((candidate.calories||0) - targetCalories);
    s += Math.max(0, 100 - calorieDiff/targetCalories*100);

    // budget penalty
    if (candidate.price && budgetPerMeal) {
      s += candidate.price <= budgetPerMeal ? 20 : -50;
    }

    // protein bonus
    s += (candidate.protein||0) * 0.5;

    // sugar penalty
    s -= (candidate.sugar||0) * 0.8;

    // history penalty if candidate is commonly eaten (encourage variety)
    if (topFoods.includes(candidate.name)) s -= 10;

    return s;
  }

  const items = Array.isArray(candidates) && candidates.length > 0 ? candidates : DEFAULT_MEALS;
  const scored = items.map((item) => ({ item, score: score(item) }));
  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, 3).map((entry) => ({
    name: entry.item.name,
    calories: entry.item.calories,
    price: entry.item.price,
    protein: entry.item.protein,
    sugar: entry.item.sugar,
    reasons: buildReason(entry.item, userProfile),
    actions: buildActions(entry.item, userProfile),
  }));
}

function buildReason(item, profile) {
  const reasons = [];
  if ((item.protein || 0) >= 20) reasons.push('Tinggi protein untuk kenyang lebih lama');
  if ((item.sugar || 0) <= 5) reasons.push('Rendah gula untuk stabilkan energi');
  if (profile.budgetPerMeal && item.price <= profile.budgetPerMeal) reasons.push('Sesuai budget');
  if (reasons.length === 0) reasons.push('Cocok dengan preferensi nutrisi Anda');
  return reasons;
}

function buildActions(item, profile) {
  const actions = [];
  actions.push(`Coba menu ${item.name} untuk variasi`);
  if (profile.goal === 'Weight Loss') actions.push('Utamakan sayur dan protein rendah lemak');
  if (profile.goal === 'Muscle Gain') actions.push('Tambahkan sumber protein untuk pemulihan otot');
  if ((item.sugar || 0) <= 5) actions.push('Hindari tambahan gula saat makan');
  return actions;
}

module.exports = { recommendMeals };
