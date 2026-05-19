import 'package:flutter/material.dart';
import '../widgets/ai_form.dart';
import '../widgets/ai_weekly_card.dart';
import '../widgets/chat_bottom_sheet.dart';

class AiNutritionScreen extends StatelessWidget {
  const AiNutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Nutrition Assistant'),
        centerTitle: true,
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personalized recommendations powered by your eating habits and goals',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              SizedBox(height: 16),
              AiForm(),
              SizedBox(height: 20),
              AiWeeklyCard(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showChatBottomSheet(context),
        label: const Text('Chat with AI'),
        icon: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}
