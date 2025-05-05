provider "aws" {
  region = "us-east-1"
}

# IAM Role and Policies
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ddb_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "sqs_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# SQS Queue
resource "aws_sqs_queue" "file_queue" {
  name = "FileQueue"
}

# DynamoDB Table with Streams
resource "aws_dynamodb_table" "file_data" {
  name         = "FileData"
  hash_key     = "FileID"
  billing_mode = "PAY_PER_REQUEST"
  stream_enabled    = true
  stream_view_type  = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "FileID"
    type = "S"
  }
}

# Lambda for SQS → DynamoDB
resource "aws_lambda_function" "sqs_to_dynamodb" {
  function_name = "SqsToDynamoDB"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/lambda_sqs_to_dynamodb.zip"

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.file_data.name
    }
  }
}

# Lambda for DynamoDB Stream Logging
resource "aws_lambda_function" "stream_logger" {
  function_name = "DynamoDBStreamLogger"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/lambda_stream_logger.zip"
}

# SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.file_queue.arn
  function_name    = aws_lambda_function.sqs_to_dynamodb.arn
  batch_size       = 10
  enabled          = true
}

# DynamoDB Stream Event Source Mapping
resource "aws_lambda_event_source_mapping" "ddb_stream_trigger" {
  event_source_arn = aws
