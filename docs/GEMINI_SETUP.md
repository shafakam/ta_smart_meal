# Gemini API Setup (short)

1. Open Google AI Studio and create a new project or select an existing one.
2. Create an API key (keep it secret) and set it in your backend `.env` as `GEMINI_API_KEY`.
3. Recommended models: `gemini-1.5-flash` (dev), `gemini-1.5-pro` or `gemini-2.5-flash` (prod/higher quality).
4. Set `GEMINI_MODEL` in `.env` if you want to change model.

Example `.env`:

GEMINI_API_KEY=AIza...your_key_here
GEMINI_MODEL=gemini-1.5-flash

Run the backend locally:

```bash
cd backend/server
npm init -y
npm install express node-fetch dotenv body-parser
node index.js
```

Important:
- Never ship the API key to the frontend.
- Summarize user data on the backend before sending to Gemini to save tokens.
