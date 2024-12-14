#!/bin/bash

# Exit on any error
set -e

# Konfiguration
AWS_REGION="us-east-1"  # Region festlegen
AWS_ACCOUNT_ID="143169511338"  # Ersetze mit deiner AWS-Kontonummer
IN_BUCKET_NAME="m346-csv-to-json-in-$(date +%s)"
OUT_BUCKET_NAME="m346-csv-to-json-out-$(date +%s)"
LAMBDA_FUNCTION_NAME="CsvToJsonFunction-$(date +%s)"  # Dynamischer Name für die Lambda-Funktion
ZIP_FILE="lambda_function.zip"
LAB_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/LabRole"

# Schritt 1: S3 Buckets erstellen
echo "Erstelle S3 Buckets..."
aws s3api create-bucket --bucket "$IN_BUCKET_NAME" --region "$AWS_REGION"
aws s3api create-bucket --bucket "$OUT_BUCKET_NAME" --region "$AWS_REGION"
echo "Buckets erstellt: $IN_BUCKET_NAME, $OUT_BUCKET_NAME"

# Schritt 2: Lambda-Funktion zippen
echo "Zippe Lambda-Funktion..."
if [ ! -f "$ZIP_FILE" ]; then
    echo "Datei $ZIP_FILE nicht gefunden. Stelle sicher, dass die Lambda-Funktion korrekt kompiliert und gezippt wurde."
    exit 1
fi

# Schritt 3: Vorhandene Lambda-Funktion löschen (falls nötig)
echo "Überprüfe, ob die Lambda-Funktion bereits existiert..."
aws lambda delete-function --function-name "$LAMBDA_FUNCTION_NAME" || echo "Lambda-Funktion existiert nicht oder konnte nicht gelöscht werden."

# Schritt 4: Lambda-Funktion deployen
echo "Deploye Lambda-Funktion..."
LAMBDA_ARN=$(aws lambda create-function \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --runtime dotnet6 \
  --role "$LAB_ROLE_ARN" \
  --handler M346_Projekt_CsvToJson::M346_Projekt_CsvToJson.Function::FunctionHandler \
  --timeout 30 \
  --memory-size 256 \
  --zip-file fileb://"$ZIP_FILE" \
  --environment "Variables={DESTINATION_BUCKET=$OUT_BUCKET_NAME}" \
  | grep -o '"FunctionArn": *"[^"]*"' | cut -d '"' -f 4)

echo "Lambda ARN: $LAMBDA_ARN"  # Debugging-Ausgabe der ARN

# Schritt 5: Berechtigung für S3 hinzufügen, damit es die Lambda-Funktion aufrufen kann
echo "Füge Berechtigung für S3 hinzu, damit es Lambda aufrufen kann..."
aws lambda add-permission \
  --function-name "$LAMBDA_ARN" \
  --principal s3.amazonaws.com \
  --statement-id "AllowS3Invoke" \
  --action "lambda:InvokeFunction" \
  --source-arn "arn:aws:s3:::$IN_BUCKET_NAME" \
  --source-account "$AWS_ACCOUNT_ID"

# Schritt 6: S3 Trigger für Lambda einrichten
echo "Füge S3 Trigger zur Lambda-Funktion hinzu..."
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
echo "Trigger hinzugefügt."

# Abschluss
echo "Setup abgeschlossen!"
echo "Eingabe-Bucket: $IN_BUCKET_NAME"
echo "Ausgabe-Bucket: $OUT_BUCKET_NAME"
