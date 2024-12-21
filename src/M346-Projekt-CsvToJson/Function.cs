using System;
using System.IO;
using System.Linq;
using System.Text;
using Amazon.Lambda.Core;
using Amazon.Lambda.S3Events;
using Amazon.S3;
using Amazon.S3.Model;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace M346_Projekt_CsvToJson
{
    public class Function
    {
        private readonly IAmazonS3 _s3Client;
        private readonly string OutputBucket = Environment.GetEnvironmentVariable("OUT_BUCKET_NAME");

        public Function() : this(new AmazonS3Client()) { }

        public Function(IAmazonS3 s3Client)
        {
            _s3Client = s3Client;
        }

        public async System.Threading.Tasks.Task FunctionHandler(S3Event evnt, ILambdaContext context)
        {
            context.Logger.LogLine("Lambda function started.");

            var s3Event = evnt.Records.FirstOrDefault();
            if (s3Event == null)
            {
                context.Logger.LogLine("No S3 event record found.");
                return;
            }

            var bucketName = s3Event.S3.Bucket.Name;
            var objectKey = s3Event.S3.Object.Key;
            
            context.Logger.LogLine($"Received event for bucket: {bucketName}, object key: {objectKey}");
            context.Logger.LogLine($"Output Bucket Environment Variable: {OutputBucket}");

            try
            {
                context.Logger.LogLine("Starting S3 GetObjectAsync to fetch file from S3 bucket.");
                var response = await _s3Client.GetObjectAsync(bucketName, objectKey);
                context.Logger.LogLine($"Successfully fetched object {objectKey} from bucket {bucketName}.");

                using (var reader = new StreamReader(response.ResponseStream))
                {
                    var csvContent = await reader.ReadToEndAsync();
                    context.Logger.LogLine($"Successfully read CSV content from {objectKey}.");

                    var jsonContent = ConvertCsvToJson(csvContent);
                    context.Logger.LogLine($"CSV content converted to JSON.");

                    var destinationKey = Path.ChangeExtension(objectKey, ".json");

                    using (var jsonStream = new MemoryStream(Encoding.UTF8.GetBytes(jsonContent)))
                    {
                        var putRequest = new PutObjectRequest
                        {
                            BucketName = OutputBucket,
                            Key = destinationKey,
                            InputStream = jsonStream,
                            ContentType = "application/json"
                        };

                        context.Logger.LogLine($"Starting S3 PutObjectAsync to upload JSON to bucket {OutputBucket}.");
                        await _s3Client.PutObjectAsync(putRequest);
                        context.Logger.LogLine($"Successfully uploaded JSON to {OutputBucket}/{destinationKey}");
                    }
                }
            }
            catch (Exception e)
            {
                context.Logger.LogLine($"Error processing {objectKey} from bucket {bucketName}. Exception: {e.Message}");
                throw;
            }

            context.Logger.LogLine("Lambda function processing completed.");
        }

        private string ConvertCsvToJson(string csvContent)
        {
            var lines = csvContent.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);
            var headers = lines.First().Split(',');

            var json = new StringBuilder();
            json.Append("[");

            foreach (var line in lines.Skip(1))
            {
                if (string.IsNullOrWhiteSpace(line)) continue;

                var values = line.Split(',');

                if (values.Length != headers.Length)
                {
                    throw new Exception("CSV line does not have the correct number of values.");
                }

                json.Append("{");

                for (int i = 0; i < headers.Length; i++)
                {
                    json.AppendFormat("\"{0}\": \"{1}\"", headers[i], values[i]);

                    if (i < headers.Length - 1)
                        json.Append(", ");
                }

                json.Append("},");
            }

            if (json[json.Length - 1] == ',')
                json.Length--;

            json.Append("]");

            return json.ToString();
        }
    }
}
