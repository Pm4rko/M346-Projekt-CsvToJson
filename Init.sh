#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}To change the delimiter (default ',') go to the function code and change the Delimiter variable${NC}"

AWS_REGION="us-east-1"
LAMBDA_FUNCTION_NAME="CsvToJsonFunction"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IN_BUCKET_NAME="m346-csv-to-json-input-${TIMESTAMP}"
OUT_BUCKET_NAME="m346-csv-to-json-output-${TIMESTAMP}"
LAB_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/LabRole"

echo -e "\n${BLUE}Configuration:${NC}"
echo "AWS Region: $AWS_REGION"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "Input Bucket: $IN_BUCKET_NAME"
echo "Output Bucket: $OUT_BUCKET_NAME"
echo "Lambda Function: $LAMBDA_FUNCTION_NAME"

echo -e "\n${BLUE}Cleaning up existing resources...${NC}"
aws lambda delete-function --function-name "$LAMBDA_FUNCTION_NAME" 2>/dev/null || true

echo -e "\n${BLUE}Creating S3 buckets...${NC}"
aws s3api create-bucket --bucket "$IN_BUCKET_NAME" --region "$AWS_REGION"
aws s3api create-bucket --bucket "$OUT_BUCKET_NAME" --region "$AWS_REGION"
echo -e "${GREEN}Buckets created successfully${NC}"

echo -e "\n${BLUE}Deploying Lambda function...${NC}"
cd src/M346-Projekt-CsvToJson
dotnet lambda deploy-function "$LAMBDA_FUNCTION_NAME" \
    --function-role "$LAB_ROLE_ARN" \

echo -e "\n${BLUE}Configuring Lambda permissions...${NC}"
aws lambda add-permission \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --statement-id S3InvokeFunction \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::$IN_BUCKET_NAME"

echo -e "\n${BLUE}Setting up S3 trigger...${NC}"
aws s3api put-bucket-notification-configuration \
    --bucket "$IN_BUCKET_NAME" \
    --notification-configuration "{
        \"LambdaFunctionConfigurations\": [{
            \"LambdaFunctionArn\": \"arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$LAMBDA_FUNCTION_NAME\",
            \"Events\": [\"s3:ObjectCreated:*\"]
        }]
    }"

echo -e "\n${GREEN}Setup completed successfully!${NC}"
echo -e "\n${BLUE}Component Names:${NC}"
echo "Input Bucket: ${IN_BUCKET_NAME}"
echo "Output Bucket: ${OUT_BUCKET_NAME}"
echo "Lambda Function: ${LAMBDA_FUNCTION_NAME}"
