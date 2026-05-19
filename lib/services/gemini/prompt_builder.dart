class PromptBuilder {
  /// Build a concise prompt to send to Gemini given a summary and a question.
  static String buildChatPrompt(Map<String, dynamic> summary, String question) {
    final buffer = StringBuffer();
    buffer.writeln('You are an AI Nutrition Assistant. Be concise, supportive, and do not provide medical diagnoses.');
    buffer.writeln('User summary:');
    buffer.writeln(summary.toString());
    buffer.writeln('\nQuestion:');
    buffer.writeln(question);
    buffer.writeln('\nRespond with a short answer, 1-3 actionable suggestions, and 1-2 reasons.');
    return buffer.toString();
  }
}
