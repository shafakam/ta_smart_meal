const assert = require('assert');
const { summarizeHistory } = require('../utils/summarizer');

const history = [
  { role: 'user', text: 'Hello' },
  { role: 'assistant', text: 'Hi there' },
];
const summary = summarizeHistory(history);
assert.strictEqual(summary.recentUser, 'Hello');
assert.strictEqual(summary.recentAssistant, 'Hi there');
assert.strictEqual(summary.messageCount, 2);
console.log('summarizer test passed');
