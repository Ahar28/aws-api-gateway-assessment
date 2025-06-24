// Default headers for CORS and JSON response
const DEFAULT_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type,Authorization",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS", 
  "Content-Type": "application/json", 
};

// Base URL for the exchange rate API
const EXCHANGE_API_BASE_URL = "https://open.er-api.com/v6/latest/";

exports.handler = async (event) => {
  // Extract the 'currency' field from the event
  const baseCurrency = event.currency;

  // Validate the 'currency' field: Check if it exists and is a non-empty string
  if (typeof baseCurrency !== 'string' || !baseCurrency.trim()) {
    return {
      statusCode: 400,
      headers: DEFAULT_HEADERS,
      body: JSON.stringify({ error: "Missing or invalid 'currency' field in the request." }),
    };
  }

  // Validate the format of the currency: Must be a 3-letter uppercase code
  if (!/^[A-Z]{3}$/.test(baseCurrency.trim().toUpperCase())) {
      return {
          statusCode: 400,
          headers: DEFAULT_HEADERS,
          body: JSON.stringify({ error: "Invalid currency format. Expected a 3-letter uppercase code (e.g., 'CAD')." }),
      };
  }

  try {
    // Constructing the API endpoint URL
    const endpoint = `${EXCHANGE_API_BASE_URL}${encodeURIComponent(baseCurrency.trim().toUpperCase())}`; 

    // Fetching exchange rate data from the API
    const res = await fetch(endpoint);

    // Handle non-OK responses from the API
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`error ${res.status}: ${errText}`);
    }

    // Parse the API response as JSON
    const data = await res.json();

    // Returning the successful response with exchange rate data
    return {
      statusCode: 200,
      headers: DEFAULT_HEADERS,
      body: JSON.stringify(data),
    };
  } catch (error) {
    return {
      statusCode: 502,
      headers: DEFAULT_HEADERS,
      body: JSON.stringify({ error: error.message || "Internal server error" }),
    };
  }
};