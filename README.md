# smart_meal_tpm

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Backend API Proxy
This project includes a small backend proxy to call the Gemini API securely.

### Setup
1. Navigate to the backend folder:
   ```powershell
   cd "D:\Materi Semester 6\ta_smart_meal\backend\server"
   ```
2. Install dependencies:
   ```powershell
   npm install
   ```
3. Copy `.env.example` to `.env` and set your Gemini API key:
   ```powershell
   copy .env.example .env
   ```
4. Start the proxy:
   ```powershell
   npm start
   ```

### Environment variables
- `GEMINI_API_KEY`: Your Google Gemini API key.
- `GEMINI_MODEL`: Gemini model name, e.g. `gemini-1.5-flash`.
- `PORT`: Backend port, default `8080`.

### Flutter integration
The frontend reads `BACKEND_URL` from the root `.env` and sends chat/referral requests to the backend proxy.
For Android emulator use `http://10.0.2.2:8080`; for a desktop or web client use `http://localhost:8080`.

## Testing and CI
- Run the Flutter analyzer:
  ```powershell
  flutter analyze
  ```
- Run the Flutter chat storage test:
  ```powershell
  flutter test test/chat_storage_test.dart
  ```
- Run the backend proxy test:
  ```powershell
  cd backend/server
  npm test
  ```

A GitHub Actions workflow is included at `.github/workflows/ci.yml` to run Flutter analyze and backend tests on push/pull request.

"# ta_smart_meal" 
"# ta_smart_meal" 
"# Smart Meal TPM" 
