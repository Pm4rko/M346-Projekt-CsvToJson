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
        private const string InputBucket = "m346-csv-to-json-in"; 
        private const string OutputBucket = "m346-csv-to-json-out";
        public Function() : this(new AmazonS3Client()) { }

        public Function(IAmazonS3 s3Client)
        {
            _s3Client = s3Client;
        }

        public async System.Threading.Tasks.Task FunctionHandler(S3Event evnt, ILambdaContext context)
        {
            var s3Event = evnt.Records.FirstOrDefault();
            if (s3Event == null)
            {
                context.Logger.LogLine("No S3 event record found.");
                return;
            }

            var bucketName = s3Event.S3.Bucket.Name;
            var objectKey = s3Event.S3.Object.Key;

            if (bucketName != InputBucket)
            {
                context.Logger.LogLine($"Event received from unexpected bucket: {bucketName}");
                return;
            }

            try
            {
                var response = await _s3Client.GetObjectAsync(bucketName, objectKey);

                using (var reader = new StreamReader(response.ResponseStream))
                {
                    var csvContent = await reader.ReadToEndAsync();

                    // CSV zu JSON konvertieren
                    var jsonContent = ConvertCsvToJson(csvContent);

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

                        await _s3Client.PutObjectAsync(putRequest);
                    }

                    context.Logger.LogLine($"Successfully converted {objectKey} to JSON and uploaded to {OutputBucket}/{destinationKey}");
                }
            }
            catch (Exception e)
            {
                context.Logger.LogLine($"Error processing {objectKey} from bucket {bucketName}. Exception: {e.Message}");
                throw;
            }
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
