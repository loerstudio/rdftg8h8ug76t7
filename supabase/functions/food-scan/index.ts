import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

// WARNING: Do not hardcode your API key here.
// Set it as an environment variable in your Supabase project settings.
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key=${GEMINI_API_KEY}`

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Extract image data from the request body
    const { image } = await req.json() // Expects a base64 encoded image string

    if (!image) {
        throw new Error('No image data provided.')
    }

    // Construct the request payload for Gemini API
    const payload = {
      contents: [
        {
          parts: [
            {
              text: "Analyze the attached image of food. Return a JSON object with your best estimate of the total calories, protein (in grams), carbohydrates (in grams), and fat (in grams). The JSON object should have only the following keys: 'calories_kcal', 'protein_g', 'carb_g', 'fat_g'. Do not return any other text or explanation, only the raw JSON object.",
            },
            {
              inline_data: {
                mime_type: 'image/jpeg',
                data: image,
              },
            },
          ],
        },
      ],
    }

    // Call the Gemini API
    const geminiResponse = await fetch(GEMINI_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    })

    if (!geminiResponse.ok) {
        const errorBody = await geminiResponse.text();
        throw new Error(`Gemini API error: ${geminiResponse.statusText} - ${errorBody}`)
    }

    const geminiData = await geminiResponse.json();

    // Extract the JSON string from the response
    const jsonString = geminiData.candidates[0].content.parts[0].text
        .replace(/```json/g, '')
        .replace(/```/g, '')
        .trim();

    const nutritionData = JSON.parse(jsonString);

    return new Response(JSON.stringify(nutritionData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
