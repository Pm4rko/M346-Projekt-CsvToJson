#!/bin/bash
set -e

TEST_FILE="test.csv"
OUTPUT_FILE="test.json"
WAIT_TIME=10

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}Did you change the Delimiter variable in Function.cs? If yes, enter it now (press Enter for default ','):${NC}"
read -r DELIMITER
DELIMITER=${DELIMITER:-,}

echo -e "${GREEN}Using delimiter: '$DELIMITER'${NC}"

echo -e "${BLUE}Cleaning up existing test files...${NC}"
rm -f ${TEST_FILE} ${OUTPUT_FILE}

IN_BUCKET_NAME=$(aws s3 ls | grep "m346-csv-to-json-input-" | tail -n 1 | awk '{print $3}')
OUT_BUCKET_NAME=$(aws s3 ls | grep "m346-csv-to-json-output-" | tail -n 1 | awk '{print $3}')

if [ -z "$IN_BUCKET_NAME" ] || [ -z "$OUT_BUCKET_NAME" ]; then
    echo "Error: Could not find input or output buckets. Please run init.sh first."
    exit 1
fi

echo -e "${GREEN}Using Input Bucket: ${IN_BUCKET_NAME}${NC}"
echo -e "${GREEN}Using Output Bucket: ${OUT_BUCKET_NAME}${NC}"
echo -e "${GREEN}Using Delimiter: ${DELIMITER}${NC}"

# Create test CSV with configured delimiter
echo "id${DELIMITER}name${DELIMITER}age${DELIMITER}city${DELIMITER}occupation
1${DELIMITER}John${DELIMITER}25${DELIMITER}New York${DELIMITER}Engineer
2${DELIMITER}Jane${DELIMITER}30${DELIMITER}San Francisco${DELIMITER}Designer
3${DELIMITER}Bob${DELIMITER}45${DELIMITER}Chicago${DELIMITER}Manager" > ${TEST_FILE}

echo -e "\n${BLUE}Input CSV file contents:${NC}"
echo "------------------------"
cat ${TEST_FILE}
echo "------------------------"

echo -e "\n${BLUE}Uploading test CSV file to S3...${NC}"
aws s3 cp ${TEST_FILE} s3://${IN_BUCKET_NAME}/

echo -e "${BLUE}Waiting for conversion (${WAIT_TIME} seconds)...${NC}"
sleep ${WAIT_TIME}

echo -e "\n${BLUE}Downloading converted JSON file...${NC}"
aws s3 cp s3://${OUT_BUCKET_NAME}/${OUTPUT_FILE} .

echo -e "\n${BLUE}Output JSON file contents:${NC}"
echo "------------------------"
cat ${OUTPUT_FILE}
echo "------------------------"

echo -e "\n${GREEN}Test completed successfully!${NC}"
echo -e "\n${BLUE}Summary:${NC}"
echo "Input file: ${TEST_FILE}"
echo "Output file: ${OUTPUT_FILE}"
echo "Delimiter: ${DELIMITER}"

echo -e "\n${BLUE}Component Names:${NC}"
echo "Input Bucket: ${IN_BUCKET_NAME}"
echo "Output Bucket: ${OUT_BUCKET_NAME}"
echo "Lambda Function: CsvToJsonFunction"
