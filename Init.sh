#!/bin/bash

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="143169511338"  # Ersetze mit deiner AWS-Kontonummer
TIMESTAMP=$(date +%Y%m%d%H%M%S)
IN_BUCKET_NAME="m346-csv-to-json-input-${TIMESTAMP}"
OUT_BUCKET_NAME="m346-csv-to-json-output-${TIMESTAMP}"
LAMBDA_FUNCTION_NAME="CsvToJsonFunction"
ZIP_FILE="lambda_function.zip"
LAB_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/LabRole"

echo "Lösche existierende Lambda-Funktion falls vorhanden..."
aws lambda delete-function --function-name "$LAMBDA_FUNCTION_NAME" 2>/dev/null || true

echo "Erstelle S3 Buckets..."
aws s3api create-bucket --bucket "$IN_BUCKET_NAME" --region "$AWS_REGION"
aws s3api create-bucket --bucket "$OUT_BUCKET_NAME" --region "$AWS_REGION"
echo "Buckets erstellt: $IN_BUCKET_NAME, $OUT_BUCKET_NAME"

echo "Stelle sicher, dass das Lambda-Projekt korrekt eingerichtet ist..."
cd src/M346-Projekt-CsvToJson

echo "Deploye Lambda-Funktion mit dotnet lambda deploy-function..."
dotnet lambda deploy-function "$LAMBDA_FUNCTION_NAME" \
    --function-role "$LAB_ROLE_ARN" \
    --environment-variables "OUT_BUCKET_NAME=$OUT_BUCKET_NAME"

echo "Füge Lambda-Berechtigung für S3 hinzu..."
aws lambda add-permission \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --statement-id S3InvokeFunction \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::$IN_BUCKET_NAME"

echo "Füge S3 Trigger für den Input-Bucket hinzu..."
aws s3api put-bucket-notification-configuration \
    --bucket "$IN_BUCKET_NAME" \
    --notification-configuration "{
        \"LambdaFunctionConfigurations\": [
            {
                \"LambdaFunctionArn\": \"arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$LAMBDA_FUNCTION_NAME\",
                \"Events\": [\"s3:ObjectCreated:*\"]
            }
        ]
    }"

aws lambda get-function-configuration --function-name "$LAMBDA_FUNCTION_NAME"

echo "Trigger hinzugefügt."

echo "Setup abgeschlossen!"
echo "Eingabe-Bucket: $IN_BUCKET_NAME"
echo "Ausgabe-Bucket: $OUT_BUCKET_NAME"
