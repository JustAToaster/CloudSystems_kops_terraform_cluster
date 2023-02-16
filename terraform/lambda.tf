data "archive_file" "reported_lambda_function_archive" {
  type = "zip"
  source_file = "./lambda/update_reported_list.py"
  output_path = "./lambda/update_reported_list.zip"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_lambda_function" "reported_lambda_function" {
  function_name = "update_reported_list"
  filename         = data.archive_file.reported_lambda_function_archive.output_path
  source_code_hash = data.archive_file.reported_lambda_function_archive.output_base64sha256
  role    = aws_iam_role.iam_for_lambda.arn
  handler = "update_reported_list.lambda_handler"
  runtime = "python3.8"
  environment {
    variables = {
      models_bucket = local.models_data_bucket_name
    }
  }
}