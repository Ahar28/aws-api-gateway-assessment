import json
import urllib.parse
import http.client

# Default headers for CORS and JSON response
DEFAULT_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS", 
    "Content-Type": "application/json"
}

# AWS lambda function to shorten a given URL
def lambda_handler(event, context):

    # Extracting the 'url' parameter from the event
    long_url = event.get("url")

    # Validating the 'url' parameter, if it exists
    if not long_url:
        return {
            "statusCode": 400,
            "headers": DEFAULT_HEADERS,
            "body": json.dumps({"error": "Missing required 'url' parameter in the request."})
        }

    conn = None
    try:
        # Encoding the long URL to make it safe for use in a query string
        encoded_long_url = urllib.parse.quote_plus(long_url)
        # Construct the API request path
        path = f"/create.php?format=simple&url={encoded_long_url}"

        # Establishing an HTTPS connection
        conn = http.client.HTTPSConnection("is.gd")
        # calling the API
        conn.request("GET", path) 
        res = conn.getresponse()

        # Handling non-200 responses from the API
        if res.status != 200:
            err_text = res.read().decode('utf-8')
            raise Exception(f"is.gd error {res.status}: {err_text}")

        # Reading and decoding the shortened URL from the API response
        short = res.read().decode('utf-8').strip()
        
        return {
            "statusCode": 200,
            "headers": DEFAULT_HEADERS,
            "body": json.dumps({"shortUrl": short})
        }
    except Exception as error:
        return {
            "statusCode": 502,
            "headers": DEFAULT_HEADERS,
            "body": json.dumps({"error": str(error)})
        }
    finally:
        # Ensuring the connection is closed to free up resources
        if conn:
            conn.close() 