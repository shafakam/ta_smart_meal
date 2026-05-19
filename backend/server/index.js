require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const fetch = require('node-fetch');
const { buildSystemPrompt, buildUserPrompt } = require('./prompts/promptTemplates');
const { analyzeUserData } = require('./analysis/ai_analysis');
const { recommendMeals } = require('./recommender');
const { summarizeHistory } = require('./utils/summarizer');

const app = express();
app.use(bodyParser.json());

const GEMINI_KEY = process.env.GEMINI_API_KEY || '';
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-1.5-flash';

async function fetchWithRetry(url, options, attempts = 2) {
  let lastErr = null;
  for (let i = 0; i < attempts; i++) {
    try {
      const r = await fetch(url, options);
      if (r.status === 429) {
        // rate limited, wait a bit and retry
        const wait = 500 * (i + 1);
        await new Promise(res => setTimeout(res, wait));
        continue;
      }
      return r;
    } catch (e) {
      lastErr = e;
      await new Promise(res => setTimeout(res, 200 * (i + 1)));
    }
  }
  throw lastErr || new Error('fetch failed after retries');
}

function isValidAssistantResponse(obj) {
  return obj && typeof obj === 'object' && typeof obj.reply === 'string' && Array.isArray(obj.reasons) && Array.isArray(obj.actions);
}

app.post('/api/ai/chat', async (req, res) => {
  try {
    const { userId, question, summary, history } = req.body;
    const compactSummary = summary || summarizeHistory(history || []);

    const system = buildSystemPrompt();
    const userPrompt = buildUserPrompt(compactSummary, question);

    const body = {
      contents: [{ parts: [{ text: system + '\n\n' + userPrompt }] }]
    };

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_KEY}`;
    const r = await fetchWithRetry(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }, 3);
    const data = await r.json();

    // Attempt to extract text output from Gemini response
    let text = '';
    try {
      if (data?.candidates && Array.isArray(data.candidates) && data.candidates[0]?.content) {
        text = data.candidates[0].content[0]?.text || '';
      } else if (data?.outputs && Array.isArray(data.outputs) && data.outputs[0]?.content) {
        text = data.outputs[0].content[0]?.text || '';
      } else if (data?.candidates && Array.isArray(data.candidates) && data.candidates[0]?.outputText) {
        text = data.candidates[0].outputText || '';
      } else {
        text = JSON.stringify(data);
      }
    } catch (e) {
      text = JSON.stringify(data);
    }

    // Try parse JSON from text
    let parsed = null;
    try {
      const firstBrace = text.indexOf('{');
      if (firstBrace >= 0) text = text.slice(firstBrace);
      parsed = JSON.parse(text);
    } catch (e) {
      parsed = { reply: text.toString().trim(), reasons: [], actions: [] };
    }

    // If parsed doesn't meet schema, try one more time with a stricter instruction append
    if (!isValidAssistantResponse(parsed)) {
      const strictSystem = system + '\n\nIMPORTANT: If you cannot produce valid JSON, output a JSON object with keys reply,reasons,actions. Never output extra text.';
      const strictBody = { contents: [{ parts: [{ text: strictSystem + '\n\n' + userPrompt }] }] };
      try {
        const r2 = await fetchWithRetry(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(strictBody) }, 2);
        const d2 = await r2.json();
        let t2 = '';
        if (d2?.candidates && Array.isArray(d2.candidates) && d2.candidates[0]?.content) {
          t2 = d2.candidates[0].content[0]?.text || '';
        } else if (d2?.outputs && Array.isArray(d2.outputs) && d2.outputs[0]?.content) {
          t2 = d2.outputs[0].content[0]?.text || '';
        } else if (d2?.candidates && Array.isArray(d2.candidates) && d2.candidates[0]?.outputText) {
          t2 = d2.candidates[0].outputText || '';
        } else {
          t2 = JSON.stringify(d2);
        }
        try {
          const firstBrace2 = t2.indexOf('{');
          if (firstBrace2 >= 0) t2 = t2.slice(firstBrace2);
          const parsed2 = JSON.parse(t2);
          if (isValidAssistantResponse(parsed2)) parsed = parsed2;
        } catch (e) {
          // keep previous parsed
        }
      } catch (e) {
        // ignore retry failure
      }
    }

    return res.json({ ok: true, data: parsed });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ ok: false, error: e.message });
  }
});

// Analysis endpoint: accepts meals, activity, weights, waterAvg, sleepAvg, targetCalories
app.post('/api/ai/analyze', (req, res) => {
  try {
    const payload = req.body || {};
    const result = analyzeUserData(payload);
    return res.json({ ok: true, analysis: result });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ ok: false, error: e.message });
  }
});

// Recommendation endpoint: accepts userProfile and candidateMeals
app.post('/api/ai/recommend', (req, res) => {
  try {
    const { userProfile, candidates } = req.body;
    const top = recommendMeals(userProfile || {}, candidates || []);
    return res.json({ ok: true, recommendations: top });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ ok: false, error: e.message });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`AI proxy listening on ${PORT}`));
