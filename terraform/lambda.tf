//Reporting lambda function
data "archive_file" "reported_lambda_function_archive" {
  type = "zip"
  source_file = "./lambda/update_reported_list.py"
  output_path = "./lambda/update_reported_list.zip"
}

resource "aws_iam_role" "iam_for_reported_lambda" {
  name = "iam_for_reported_lambda"
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

# Give full S3 access to the rds lambda function
resource "aws_iam_role_policy_attachment" "rds_lambda_role_attach" {
  role       = aws_iam_role.iam_for_reported_lambda.name
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ])
  policy_arn = each.value
}

resource "aws_lambda_function" "reported_lambda_function" {
  function_name = "update_reported_list"
  filename         = data.archive_file.reported_lambda_function_archive.output_path
  source_code_hash = data.archive_file.reported_lambda_function_archive.output_base64sha256
  role    = aws_iam_role.iam_for_reported_lambda.arn
  handler = "update_reported_list.handler"
  runtime = "python3.8"
  environment {
    variables = {
      models_bucket = local.models_data_bucket_name
    }
  }
  # Increase time limit (default is 3 seconds, too low)
  timeout = 180
}

//Training check lambda function
data "archive_file" "training_check_schedule_lambda_function_archive" {
  type = "zip"
  source_file = "./lambda/training_check_schedule.py"
  output_path = "./lambda/training_check_schedule.zip"
}

resource "aws_iam_role" "iam_for_training_lambda" {
  name = "iam_for_training_lambda"
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

# Give full SageMaker and S3 access to the training schedule lambda function
resource "aws_iam_role_policy_attachment" "training_lambda_role_attach" {
  role       = aws_iam_role.iam_for_training_lambda.name
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess", 
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ])
  policy_arn = each.value
}

resource "aws_lambda_function" "training_check_schedule_lambda_function" {
  function_name = "training_check_schedule"
  filename         = data.archive_file.training_check_schedule_lambda_function_archive.output_path
  source_code_hash = data.archive_file.training_check_schedule_lambda_function_archive.output_base64sha256
  role    = aws_iam_role.iam_for_training_lambda.arn
  handler = "training_check_schedule.handler"
  runtime = "python3.8"
  environment {
    variables = {
      models_bucket = local.models_data_bucket_name
      min_new_training_data = local.min_new_training_data
      min_new_validation_data = local.min_new_validation_data

      min_training_data = local.min_training_data
      min_validation_data = local.min_validation_data

      sagemaker_instance_name = aws_sagemaker_notebook_instance.training_notebook_instance.name
    }
  }
  # Increase time limit (default is 3 seconds, too low)
  timeout = 180
}

resource "aws_cloudwatch_event_rule" "every_n_minutes" {
  name        = "every_n_minutes_rule"
  description = "trigger lambda every n minutes"

  schedule_expression = "rate(${local.training_check_frequency_minutes} minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.every_n_minutes.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.training_check_schedule_lambda_function.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.training_check_schedule_lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_n_minutes.arn
}
