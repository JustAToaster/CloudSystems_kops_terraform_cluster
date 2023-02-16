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

resource "aws_iam_policy_attachment" "sm_full_access_attach" {
  name = "sm-full-access-attachment"
  roles = [aws_iam_role.notebook_iam_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_sagemaker_code_repository" "git_repo" {
  code_repository_name = "yolov5"
  
  git_config {
    repository_url = "https://github.com/justatoaster/yolov5.git"
  }
}

resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "notebook_config" {
  name = "sm-lifecycle-config"
  on_create = filebase64("./sagemaker/on-create.sh")
  on_start = filebase64("./sagemaker/on-start.sh")
}

resource "aws_sagemaker_notebook_instance" "training_notebook_instance" {
  name = "sagemaker_training_notebook"
  role_arn = aws_iam_role.notebook_iam_role.arn
  instance_type = "ml.t3.medium"
  lifecycle_config_name = aws_sagemaker_notebook_instance_lifecycle_configuration.notebook_config.name
  default_code_repository = aws_sagemaker_code_repository.git_repo.code_repository_name
}