// Simple heuristic ML-like analysis for nutrition app
function sum(arr) { return arr.reduce((s, v) => s + v, 0); }

function avg(arr) { return arr.length ? sum(arr) / arr.length : 0; }

function hourlyHistogram(meals) {
  const hist = Array(24).fill(0);
  meals.forEach(m => {
    try {
      const d = new Date(m.time);
      const h = d.getHours();
      hist[h] += 1;
    } catch (e) {}
  });
  return hist;
}

function linearTrend(points) {
  // points: [{t: timestamp, value: number}]
  if (!points.length) return { slope: 0, intercept: 0 };
  const n = points.length;
  let sx = 0, sy = 0, sxx = 0, sxy = 0;
  const xs = points.map((p,i)=>i); // use index to avoid large timestamps
  const ys = points.map(p=>p.value);
  for (let i=0;i<n;i++){
    const x = xs[i]; const y = ys[i];
    sx += x; sy += y; sxx += x*x; sxy += x*y;
  }
  const denom = (n*sxx - sx*sx) || 1;
  const slope = (n*sxy - sx*sy)/denom;
  const intercept = (sy - slope*sx)/n;
  return { slope, intercept };
}

function analyzeUserData({ meals = [], activity = [], weights = [], waterAvg = 0, sleepAvg = 0, targetCalories=2000, goal='maintain' }) {
  // meals: [{calories, protein, sugar, time, name}]
  const byDay = {};
  meals.forEach(m => {
    const d = new Date(m.time).toISOString().slice(0,10);
    byDay[d] = byDay[d] || { calories: 0, protein: 0, sugar: 0, count:0 };
    byDay[d].calories += (m.calories||0);
    byDay[d].protein += (m.protein||0);
    byDay[d].sugar += (m.sugar||0);
    byDay[d].count += 1;
  });

  const dailyCalories = Object.values(byDay).map(d=>d.calories);
  const weeklyCalories = sum(dailyCalories.slice(-7));
  const avgDailyCalories = avg(dailyCalories.slice(-7));
  const proteinList = meals.map(m=>m.protein||0);
  const sugarList = meals.map(m=>m.sugar||0);
  const proteinAvg = avg(proteinList);
  const sugarTotal = sum(sugarList);
  const calorieTotal = sum(meals.map(m=>m.calories||0))||1;
  const sugarPercent = (sugarTotal / calorieTotal) * 100;

  const mealTimes = hourlyHistogram(meals);

  // weight trend
  const weightPoints = weights.map(w=>({t: new Date(w.date).getTime(), value: w.weight}));
  const trend = linearTrend(weightPoints);

  // simple detections
  const overeating = avgDailyCalories > targetCalories * 1.05;
  const highSugar = sugarPercent > 10; // heuristic
  const proteinDeficit = proteinAvg < 50; // grams average heuristic
  const lowSleep = sleepAvg < 6.5;
  const lowHydration = waterAvg < 1.5; // liters

  // prediction: project weight change per week using slope (value per index)
  const predictedWeeklyChange = trend.slope * 7; // rough

  const topFoodsMap = {};
  meals.forEach(m=>{ if (m.name) topFoodsMap[m.name]=(topFoodsMap[m.name]||0)+1; });
  const topFoods = Object.entries(topFoodsMap).sort((a,b)=>b[1]-a[1]).slice(0,5).map(e=>e[0]);

  const summary = {
    weeklyCalories,
    avgDailyCalories,
    proteinAvg,
    sugarPercent: Math.round(sugarPercent*10)/10,
    mealTimes,
    predictedWeeklyChange,
    overeating,
    highSugar,
    proteinDeficit,
    lowSleep,
    lowHydration,
    topFoods,
  };

  return summary;
}

module.exports = { analyzeUserData };
