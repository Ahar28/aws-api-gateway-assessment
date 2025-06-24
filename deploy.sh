#!/bin/bash

set -euo pipefail

# --- VARIABLES ---
# GitHub repository URL and AWS configuration
GIT_REPO_URL="https://github.com/Ahar28/aws-api-gateway-assessment"
REGION="${AWS_REGION:-$(aws configure get region)}"
STACK_NAME="scanSource-stack"
REPO_DIR="aws-api-gateway-assessment"

# --- Cloning OR Updating the Repo ---
echo " ##Fetching source code from GitHub "

if [ -d "$REPO_DIR" ]; then
  echo "Repository directory '$REPO_DIR' already exists. Pulling latest changes"
  (cd "$REPO_DIR" && git pull)
else
  echo "Cloning repository..."
  git clone "$GIT_REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
echo "Working from directory: $(pwd)"


# --- PACKAGING AND DEPLOYING THE BACKEND INFRASTRUCTURE ---
echo -e "\n ### Packaging Lambda functions"

# File paths based on the repository structure
TEMPLATE_FILE="cloudformation/main.yml"
LAMBDA1_DIR="lambdas/lambda1" # Node.js function
LAMBDA2_DIR="lambdas/lambda2" # Python function
BUILD_DIR="build"
mkdir -p ${BUILD_DIR}
LAMBDA1_ZIP="lambda1-nodejs.zip"
LAMBDA2_ZIP="lambda2-python.zip"

echo "Zipping ${LAMBDA1_DIR}"
(cd ${LAMBDA1_DIR} && zip -rq ../../${BUILD_DIR}/${LAMBDA1_ZIP} .)
echo "Zipping ${LAMBDA2_DIR}"
(cd ${LAMBDA2_DIR} && zip -rq ../../${BUILD_DIR}/${LAMBDA2_ZIP} .)
echo "Lambda functions packaged successfully."

echo -e "\n -- Starting Backend CloudFormation Deployment ---"
echo "Running initial deployment to create resources ( the S3 code bucket)"
aws cloudformation deploy \
  --template-file ${TEMPLATE_FILE} \
  --stack-name ${STACK_NAME} \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ${REGION} \
  --parameter-overrides \
    DeployLambdas=false \
    UrlShortenerLambdaS3Key="-" \
    ConversionRateLambdaS3Key="-"

# Fetching the physical ID of the S3 bucket created by CloudFormation
CODE_BUCKET_NAME_IN_TEMPLATE="LambdaCodeBucket"
CODE_BUCKET_PHYSICAL_ID=$(aws cloudformation describe-stack-resource --stack-name ${STACK_NAME} --logical-resource-id ${CODE_BUCKET_NAME_IN_TEMPLATE} --query "StackResourceDetail.PhysicalResourceId" --output text)

# Uploading the packaged Lambda function code to the S3 bucket
echo "Uploading packaged code to S3 bucket: ${CODE_BUCKET_PHYSICAL_ID}"
aws s3 cp ${BUILD_DIR}/${LAMBDA1_ZIP} s3://${CODE_BUCKET_PHYSICAL_ID}/${LAMBDA1_ZIP}
aws s3 cp ${BUILD_DIR}/${LAMBDA2_ZIP} s3://${CODE_BUCKET_PHYSICAL_ID}/${LAMBDA2_ZIP}

# Second deployment to update Lambda functions with the uploaded code
echo "##Running second deployment to update Lambda functions with uploaded code"
aws cloudformation deploy \
  --template-file ${TEMPLATE_FILE} \
  --stack-name ${STACK_NAME} \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ${REGION} \
  --parameter-overrides \
    DeployLambdas=true \
    UrlShortenerLambdaS3Key=${LAMBDA2_ZIP} \
    ConversionRateLambdaS3Key=${LAMBDA1_ZIP}

echo "Backend deployment complete!"

# --- Configuring & deploying the frontend application ---
echo -e "\n--- Starting Frontend Deployment ---"

# Helper function to fetch outputs from the deployed stack
get_output() {
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" \
    --output text
}

# Fetching all necessary outputs from the backend stack
API_INVOKE_URL=$(get_output ApiInvokeURL)
URL_SHORT_ENDPOINT=$(get_output UrlShortEndpoint)
CONVERSION_ENDPOINT=$(get_output ConversionEndpoint)
POOL_DOMAIN_PREFIX=$(get_output UserPoolDomainPrefix)
CLIENT_ID=$(get_output UserPoolAppClientId)
CLIENT_SECRET=$(get_output UserPoolAppClientSecret)
FRONTEND_URL=$(get_output FrontEndURL)
COGNITO_CALLBACK_URL=$(get_output CognitoCallbackURL)

# Building Cognito domain
COGNITO_DOMAIN="https://${POOL_DOMAIN_PREFIX}.auth.${REGION}.amazoncognito.com"

echo "Fetched configuration from CloudFormation:"
echo "→ API Invoke URL:   $API_INVOKE_URL"
echo "→ Cognito Domain:   $COGNITO_DOMAIN"
echo "→ Cognito Client ID:  $CLIENT_ID"

# Defining paths for the assets
ASSETS_DIR="assets"
CONFIG_FILE="${ASSETS_DIR}/config.js"
INDEX_FILE="${ASSETS_DIR}/index.html"

# Generating config.js file inside the assets directory
echo "Writing configuration to $CONFIG_FILE"
cat > "$CONFIG_FILE" <<EOF
window._config = {
  apiInvokeUrl:       "$API_INVOKE_URL",
  urlShortEndpoint:   "$URL_SHORT_ENDPOINT",
  conversionEndpoint: "$CONVERSION_ENDPOINT",
  cognitoDomain:      "$COGNITO_DOMAIN",
  clientId:           "$CLIENT_ID",
  clientSecret:       "$CLIENT_SECRET",
  cognitoCallbackUrl: "$COGNITO_CALLBACK_URL"
};
EOF

# Determine the frontend S3 bucket name
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET_NAME="scansource-frontend-${AWS_ACCOUNT_ID}-${REGION}"

# Uploading index.html & config.js to the S3 bucket
echo "Uploading frontend files to s3://$BUCKET_NAME"
aws s3 cp "$INDEX_FILE"  "s3://$BUCKET_NAME/index.html" --content-type "text/html"
aws s3 cp "$CONFIG_FILE" "s3://$BUCKET_NAME/config.js"  --content-type "application/javascript"

echo -e "\Frontend deployment complete!"
echo " Application is now live"
echo "   $FRONTEND_URL"