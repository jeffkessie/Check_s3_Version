# S3 Bucket for compliance reports
resource "aws_s3_bucket" "GDIT" {
  bucket = "leidos-bucket"   

  tags = {
    Name        = "Leidos Compliance Reports"
    Environment = "PROD"
  }
}

# Enable versioning on the bucket
resource "aws_s3_bucket_versioning" "GDIT_versioning" {
  bucket = aws_s3_bucket.GDIT.id

  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket" "TEST1" {
  bucket = "leidos-bucket"   

  tags = {
    Name        = "Leidos Compliance Reports"
    Environment = "PROD"
  }
}

# Enable versioning on the bucket
resource "aws_s3_bucket_versioning" "GDIT_versioning" {
  bucket = aws_s3_bucket.TEST1.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket" "TEST2" {
  bucket = "leidos-bucket"   

  tags = {
    Name        = "Leidos Compliance Reports"
    Environment = "PROD"
  }
}

# Enable versioning on the bucket
resource "aws_s3_bucket_versioning" "GDIT_versioning" {
  bucket = aws_s3_bucket.TEST2.id

  versioning_configuration {
    status = "Disabled"
  }
}










resource "aws_s3_bucket_lifecycle_configuration" "GDIT_lifecycle" {
  bucket = aws_s3_bucket.GDIT.id

  rule {
    id     = "ExpireOldReports"
    status = "Enabled"

    expiration {
      days = 50
    }

    filter {}
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "s3_compliance_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}





resource "aws_lambda_function" "compliance" {
  filename         = "lambda_compliance.zip"
  function_name    = "s3_compliance_report"
  handler          = "lambda_compliance.lambda_handler"
  runtime          = "python3.10"
  role             = aws_iam_role.lambda_role.arn
  timeout          = 60

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.GDIT.bucket
      # S3_KEY    = "compliance_report.xlsx"  
    }
  }
}


























resource "aws_cloudwatch_event_rule" "weekly_schedule" {
  name                = "compliance-weekly"
  # cron(min hour day-of-month month day-of-week year)
  schedule_expression = "cron(0 15 ? * FRI *)" 
  description         = "Weekly trigger for compliance Lambda every Friday at 3 PM UTC"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.weekly_schedule.name
  target_id = "compliance-lambda"
  arn       = aws_lambda_function.compliance.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_schedule.arn
}
