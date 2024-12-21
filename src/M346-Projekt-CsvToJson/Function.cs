/*
 * CSV to JSON Converter Lambda Function
 * 
 * Author: Marko Piric
 * Date: 11.December.2024
 * Version: 1.0
 * 
 * Description: AWS Lambda function that converts CSV files to JSON format
 * Source: Custom implementation based on AWS Lambda, S3 SDK, M346 and ChatGPT
 * 
 * This Lambda function is triggered by S3 events when a CSV file is uploaded.
 * It converts the CSV file to a formatted JSON file and saves it to the output bucket.
 */

using System;
using System.Linq;
using System.Text;
using System.IO;
using System.Threading.Tasks;
using Amazon.Lambda.Core;
using Amazon.Lambda.S3Events;
using Amazon.S3;
using Amazon.S3.Model;

// Configure Lambda serializer
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace M346_Projekt_CsvToJson
{
    public class Function
    {
        
        // S3 client for AWS operations
        private readonly IAmazonS3 _s3Client;
        
        // Delimiter variable, change to use other delimiter
        private readonly string Delimiter = ",";

        // Default constructor using default S3 client
        public Function() : this(new AmazonS3Client()) { }

        // Constructor with custom S3 client for testing
        public Function(IAmazonS3 s3Client)
        {
            _s3Client = s3Client;
        }

        /// <summary>
        /// Finds the most recently created output bucket
        /// </summary>
        /// <returns>Name of the latest output bucket</returns>
        private async Task<string> GetLatestOutputBucket()
        {
            var response = await _s3Client.ListBucketsAsync();
            return response.Buckets
                .Where(b => b.BucketName.StartsWith("m346-csv-to-json-output-"))
                .OrderByDescending(b => b.CreationDate)
                .First().BucketName;
        }

        /// <summary>
        /// Main Lambda function handler
        /// </summary>
        /// <param name="evnt">S3 event containing file information</param>
        /// <param name="context">Lambda context for logging</param>
        public async Task FunctionHandler(S3Event evnt, ILambdaContext context)
        {
            context.Logger.LogLine("Lambda function started.");
            context.Logger.LogLine($"Delimiter: {Delimiter}");

            // Get the first S3 event record
            var s3Event = evnt.Records.FirstOrDefault();
            if (s3Event == null)
            {
                context.Logger.LogLine("No S3 event record found.");
                return;
            }

            // Extract bucket and file information
            var bucketName = s3Event.S3.Bucket.Name;
            var objectKey = s3Event.S3.Object.Key;
            var outputBucket = await GetLatestOutputBucket();
            
            // Log processing details
            context.Logger.LogLine($"Processing file: {objectKey} from bucket: {bucketName}");
            context.Logger.LogLine($"Using delimiter: {Delimiter}");
            context.Logger.LogLine($"Output bucket: {outputBucket}");

            try
            {
                // Read the CSV file from S3
                var response = await _s3Client.GetObjectAsync(bucketName, objectKey);
                string csvContent;
                using (var reader = new StreamReader(response.ResponseStream))
                {
                    csvContent = await reader.ReadToEndAsync();
                }

                // Convert CSV to JSON
                var jsonContent = ConvertCsvToJson(csvContent);
                var destinationKey = Path.ChangeExtension(objectKey, ".json");

                // Upload JSON file to output bucket
                using (var jsonStream = new MemoryStream(Encoding.UTF8.GetBytes(jsonContent)))
                {
                    var putRequest = new PutObjectRequest
                    {
                        BucketName = outputBucket,
                        Key = destinationKey,
                        InputStream = jsonStream,
                        ContentType = "application/json"
                    };

                    await _s3Client.PutObjectAsync(putRequest);
                    context.Logger.LogLine($"Successfully converted and uploaded to {outputBucket}/{destinationKey}");
                }
            }
            catch (Exception e)
            {
                context.Logger.LogLine($"Error: {e.Message}");
                throw;
            }
        }

        /// <summary>
        /// Converts CSV content to formatted JSON
        /// </summary>
        /// <param name="csvContent">Input CSV string</param>
        /// <returns>Formatted JSON string</returns>
        private string ConvertCsvToJson(string csvContent)
        {
            // Split CSV into lines and get headers
            var lines = csvContent.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);
            var headers = lines.First().Split(Delimiter);
            var json = new StringBuilder();
            
            // Start JSON array
            json.AppendLine("[");
            
            // Process each data line
            var validLines = lines.Skip(1)
                                .Where(line => !string.IsNullOrWhiteSpace(line))
                                .ToList();

            for (int lineIndex = 0; lineIndex < validLines.Count; lineIndex++)
            {
                var values = validLines[lineIndex].Split(Delimiter);
                
                // Validate line format
                if (values.Length != headers.Length)
                {
                    throw new Exception($"Invalid CSV format: Line {lineIndex + 2} has {values.Length} values but should have {headers.Length}");
                }
                
                // Start object
                json.AppendLine("    {");
                
                // Add each field
                for (int i = 0; i < headers.Length; i++)
                {
                    json.Append("        \"")
                        .Append(headers[i].Trim())
                        .Append("\": \"")
                        .Append(values[i].Trim())
                        .Append("\"");
                    
                    // Add comma if not last field
                    if (i < headers.Length - 1)
                        json.AppendLine(",");
                    else
                        json.AppendLine();
                }
                
                // Close object
                json.Append("    }");
                if (lineIndex < validLines.Count - 1)
                    json.AppendLine(",");
                else
                    json.AppendLine();
            }
            
            // Close JSON array
            json.AppendLine("]");
            
            return json.ToString();
        }
    }
}
