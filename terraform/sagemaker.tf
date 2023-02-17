data "aws_iam_policy_document" "sm_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    
    principals {
      type = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "notebook_iam_role" {
  name = "sm_notebook_role"
  assume_role_policy = data.aws_iam_policy_document.sm_assume_role_policy.json
}

//The SageMaker instance needs both S3 access for training data and SageMaker access to stop itself
resource "aws_iam_policy_attachment" "sm_s3_full_access_attach" {
  name = "sm-full-access-attachment"
  roles = [aws_iam_role.notebook_iam_role.name]
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess", 
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ])
  policy_arn = each.value
}

//Git repositories are checked out after lifecycle scripts: we will just clone the repository inside the script
/*
resource "aws_sagemaker_code_repository" "git_repo" {
  code_repository_name = "yolov5"
  
  git_config {
    repository_url = "https://github.com/justatoaster/yolov5.git"
  }
}
*/

resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "notebook_config" {
  name = "sm-lifecycle-config"
  on_create = filebase64("./sagemaker/on-create.sh")
  on_start = filebase64("./sagemaker/on-start.sh")
}

resource "aws_cloudwatch_log_group" "training_log_group" {
  name = "JustAToaster_TrainingTasks"
}

resource "aws_cloudwatch_log_stream" "yolov5_log_stream" {
  name = "YOLOv5"
  log_group_name = aws_cloudwatch_log_group.training_log_group.name
}


resource "aws_sagemaker_notebook_instance" "training_notebook_instance" {
  name = "sagemaker-training-notebook"
  role_arn = aws_iam_role.notebook_iam_role.arn
  instance_type = "ml.t3.medium"
  lifecycle_config_name = aws_sagemaker_notebook_instance_lifecycle_configuration.notebook_config.name
  volume_size = 5
  //default_code_repository = aws_sagemaker_code_repository.git_repo.code_repository_name
  //Can't insert environment variables, so we have to use the tag to pass the bucket name
  tags = {
    models_bucket = local.models_data_bucket_name
    num_training_epochs = local.num_training_epochs
    num_finetuning_epochs = local.num_finetuning_epochs
    batch_size = local.batch_size
    log_group_name = aws_cloudwatch_log_group.training_log_group.name
    log_stream_name = aws_cloudwatch_log_stream.yolov5_log_stream.name
  }
}