#!/bin/bash

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="143169511338"  # Ersetze mit deiner AWS-Kontonummer
IN_BUCKET_NAME="m346-csv-to-json-in"
OUT_BUCKET_NAME="m346-csv-to-json-out"
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

if [ -f "$ZIP_FILE" ]; then
    echo "Die Datei $ZIP_FILE existiert bereits. Lösche sie."
    rm "$ZIP_FILE"
fi

echo "Zippe Lambda-Funktion..."
zip -r "$ZIP_FILE" src/M346-Projekt-CsvToJson/*

echo "Überprüfe, ob die Lambda-Funktion bereits existiert..."
aws lambda delete-function --function-name "$LAMBDA_FUNCTION_NAME" || echo "Lambda-Funktion existiert nicht oder konnte nicht gelöscht werden."

echo "Deploye Lambda-Funktion..."
LAMBDA_ARN=$(aws lambda create-function \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --runtime dotnet8 \
  --role "$LAB_ROLE_ARN" \
  --handler M346_Projekt_CsvToJson::M346_Projekt_CsvToJson.Function::FunctionHandler \
  --timeout 30 \
  --memory-size 256 \
  --zip-file fileb://"$ZIP_FILE" \
  --environment "Variables={DESTINATION_BUCKET=$OUT_BUCKET_NAME}" \
  | grep -o '"FunctionArn": *"[^"]*"' | cut -d '"' -f 4)

echo "Lambda ARN: $LAMBDA_ARN"

echo "Füge Berechtigung für S3 hinzu, damit es Lambda aufrufen kann..."
aws lambda add-permission \
  --function-name "$LAMBDA_ARN" \
  --principal s3.amazonaws.com \
  --statement-id "AllowS3Invoke" \
  --action "lambda:InvokeFunction" \
  --source-arn "arn:aws:s3:::$IN_BUCKET_NAME" \
  --source-account "$AWS_ACCOUNT_ID"

echo "Füge S3 Trigger für den Input-Bucket hinzu..."
aws s3api put-bucket-notification-configuration \
  --bucket "$IN_BUCKET_NAME" \
  --notification-configuration "{
    \"LambdaFunctionConfigurations\": [
      {
        \"LambdaFunctionArn\": \"$LAMBDA_ARN\",
        \"Events\": [\"s3:ObjectCreated:*\"] 
      }
    ]
  }"


echo "Füge S3 Trigger für den Output-Bucket hinzu..."
aws s3api put-bucket-notification-configuration \
  --bucket "$OUT_BUCKET_NAME" \
  --notification-configuration "{
    \"LambdaFunctionConfigurations\": [
      {
        \"LambdaFunctionArn\": \"$LAMBDA_ARN\",
        \"Events\": [\"s3:ObjectCreated:*\"] 
      }
    ]
  }"

echo "Trigger hinzugefügt."

echo "Setup abgeschlossen!"
echo "Eingabe-Bucket: $IN_BUCKET_NAME"
echo "Ausgabe-Bucket: $OUT_BUCKET_NAME"
