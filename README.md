# AWS API Gateway with Cognito Authentication

## Overview

This repository provides a comprehensive solution for deploying an AWS API Gateway secured with Cognito authentication and integrated with two AWS Lambda functions. The infrastructure is fully managed using AWS CloudFormation scripts, and deployment automation is handled via a custom Bash script (`deploy.sh`).

## Architecture

This solution leverages AWS CloudFormation for infrastructure-as-code (IaC), ensuring consistent, repeatable, and automated deployments. The architecture comprises:

- **AWS API Gateway**: Acts as the entry point for API requests, managing security, request validation, and integration with backend Lambda functions.
- **AWS Cognito**: Provides authentication via User Pools, ensuring that only authenticated users can access API endpoints.
- **AWS Lambda Functions**:
  - **URL Shortener (Python)**: Integrates with the external `is.gd` service to shorten URLs provided by users.
  - **Currency Conversion (Node.js)**: Fetches real-time currency conversion data from an external API (ExchangeRate-API).
- **AWS S3**: Hosts Lambda function deployment packages and the frontend HTML application.
- **AWS IAM**: Provides the necessary permissions for services to interact with each other securely (e.g., allowing API Gateway to invoke Lambda).
- **AWS CloudFormation**: Defines all the above resources as code, allowing for one-click deployment.

### Frontend Integration

The frontend (index.html) communicates directly with the API Gateway endpoints. It dynamically loads configuration values (config.js) generated during deployment. Authentication tokens are obtained through Cognito’s hosted UI, facilitating secure API calls.

### Solution Flow

1. **User Authentication**: Users authenticate via AWS Cognito, obtaining a JWT token for secure API access.
2. **API Request Handling**:
   - Authenticated users invoke API endpoints through API Gateway.
   - API Gateway validates the JWT token via Cognito Authorizer.
   - Validated requests are forwarded to corresponding Lambda functions.
3. **Lambda Function Execution**:
   - Lambda functions process incoming requests, call external services, and return the processed results back to API Gateway.
   - API Gateway formats and sends the final response back to the client.
4. **Frontend Application**: Users interact with the API through a simple HTML page hosted on AWS S3, utilizing dynamically generated configuration (`config.js`) to handle requests and responses securely.

---

## Repository Structure

```
/aws-api-gateway-assessment
├── README.md
├── cloudformation
│   └── main.yml
├── lambdas
│   ├── lambda1 (Node.js Lambda)
│   │   └── index.js
│   └── lambda2 (Python Lambda)
│       └── index.py
├── assets
│   ├── index.html
│   └── config.js (generated dynamically)
└── deploy.sh
```

---

## External Services

- **URL Shortener**: [is.gd](https://is.gd/) - Simple URL shortening API.
- **Currency Conversion**: [ExchangeRate-API](https://open.er-api.com/v6/latest/USD) - Real-time currency exchange rates API.

---

## Deployment Guide

### Prerequisites

- AWS CLI installed and configured.
- Git installed.
- AWS account with necessary permissions.

### Steps to Create and Configure Cognito User Pool

The Cognito User Pool is automatically created and configured via the CloudFormation script during deployment. If customization is required, adjust the `cloudformation/main.yml` file accordingly.

### Deployment Using CloudFormation Script

1. **Clone the Repository**

   ```bash
   git clone https://github.com/Ahar28/aws-api-gateway-assessment.git
   cd aws-api-gateway-assessment
   ```

2. **Make the Deployment Script Executable**

   ```bash
   chmod +x deploy.sh
   ```

3. **Deploy the Infrastructure**

   ```bash
   ./deploy.sh
   ```

---

## Invoking Lambda Functions via API Gateway

- Obtain an authentication token from Cognito’s hosted UI.
- Use API endpoints:
  - URL Shortener: `<ApiInvokeURL>/urlshort`
  - Currency Conversion: `<ApiInvokeURL>/conversion`

### Example Requests

#### Using Curl

**URL Shortener**

```bash
curl -X POST \
     -H "Authorization: Bearer <your-cognito-token>" \
     -d '{"url":"https://www.example.com"}' \
     <ApiInvokeURL>/urlshort
```

**Currency Conversion**

```bash
curl -X POST \
     -H "Authorization: Bearer <your-cognito-token>" \
     -d '{"currency":"USD"}' \
     <ApiInvokeURL>/conversion
```

#### Using Postman

- **Request Type**: POST
- **Headers**:
  - `Authorization`: `Bearer <your-cognito-token>`
  - `Content-Type`: `application/json`
- **Body (raw JSON)**:
  - **URL Shortener**:
    ```json
    { "url": "https://www.example.com" }
    ```
  - **Currency Conversion**:
    ```json
    { "currency": "USD" }
    ```
- **Endpoint**: `<ApiInvokeURL>/urlshort` or `<ApiInvokeURL>/conversion`

### Expected Responses

- **URL Shortener**: Shortened URL.
- **Currency Conversion**: Currency rates.

---

## Assumptions and Limitations

- AWS Free Tier eligible services are utilized.
- Lambdas are deployed after code uploads to S3.
- External services require no additional authentication.

---

## Additional Configuration

- Confirm AWS CLI credentials and region settings.