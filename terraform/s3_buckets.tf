// S3 bucket to store kops state.
resource "aws_s3_bucket" "kops_state" {
  bucket        = local.kops_state_bucket_name
  force_destroy = true
  tags          = "${merge(local.tags)}"
}

resource "aws_s3_bucket_acl" "s3_kops_state_bucket_acl" {
  bucket = aws_s3_bucket.kops_state.bucket
  acl    = "public-read-write"
}

// S3 bucket to store the YOLOv5 models, training data and the report list
resource "aws_s3_bucket" "models_data" {
  bucket        = local.models_data_bucket_name
  force_destroy = true
  tags          = "${merge(local.tags)}"
}

resource "aws_s3_bucket_acl" "s3_models_data_bucket_acl" {
  bucket = aws_s3_bucket.models_data.bucket
  acl    = "public-read-write"
}

//Upload data to S3 bucket
resource "aws_s3_object" "s3_object_models" {
  for_each = fileset("./s3_data/", "**")
  bucket = aws_s3_bucket.models_data.id
  key = each.value
  source = "./s3_data/${each.value}"
  etag = filemd5("./s3_data/${each.value}")
}