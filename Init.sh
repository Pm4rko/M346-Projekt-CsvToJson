#!/bin/bash

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="143169511338"  # Ersetze mit deiner AWS-Kontonummer
IN_BUCKET_NAME="m346-csv-to-json-input"
OUT_BUCKET_NAME="m346-csv-to-json-output"
LAMBDA_FUNCTION_NAME="CsvToJsonFunction"
ZIP_FILE="lambda_function.zip"
LAB_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/LabRole"

echo "Überprüfe, ob die Buckets existieren und lösche sie, wenn ja..."

if aws s3 ls "s3://$IN_BUCKET_NAME" >/dev/null 2>&1; then
    echo "Lösche Input-Bucket $IN_BUCKET_NAME"
    aws s3 rb "s3://$IN_BUCKET_NAME" --force
fi

if aws s3 ls "s3://$OUT_BUCKET_NAME" >/dev/null 2>&1; then
    echo "Lösche Output-Bucket $OUT_BUCKET_NAME"
    aws s3 rb "s3://$OUT_BUCKET_NAME" --force
fi

echo "Erstelle S3 Buckets..."
aws s3api create-bucket --bucket "$IN_BUCKET_NAME" --region "$AWS_REGION"
aws s3api create-bucket --bucket "$OUT_BUCKET_NAME" --region "$AWS_REGION"
echo "Buckets erstellt: $IN_BUCKET_NAME, $OUT_BUCKET_NAME"

echo "Stelle sicher, dass das Lambda-Projekt korrekt eingerichtet ist..."
cd src/M346-Projekt-CsvToJson

echo "Deploye Lambda-Funktion mit dotnet lambda deploy-function..."
dotnet lambda deploy-function "$LAMBDA_FUNCTION_NAME" --function-role "$LAB_ROLE_ARN"

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

echo "Trigger hinzugefügt."

echo "Setup abgeschlossen!"
echo "Eingabe-Bucket: $IN_BUCKET_NAME"
echo "Ausgabe-Bucket: $OUT_BUCKET_NAME"
