// Very small summarizer: compacts recent history into a brief bullet summary.
function summarizeHistory(history) {
  if (!history || !Array.isArray(history) || history.length === 0) return { note: 'No recent chat history' };
  // take last up to 10 messages, prefer user messages
  const window = history.slice(-10);
  const userMsgs = window.filter(m => m.role === 'user').map(m => m.text).join(' | ');
  const assistantMsgs = window.filter(m => m.role === 'assistant').map(m => m.text).join(' | ');
  const summary = {
    recentUser: userMsgs.substring(0, 800),
    recentAssistant: assistantMsgs.substring(0, 800),
    messageCount: window.length
  };
  return summary;
}

module.exports = { summarizeHistory };
