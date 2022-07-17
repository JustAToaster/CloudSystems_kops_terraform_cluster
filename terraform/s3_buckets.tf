// S3 bucket to store kops state.
resource "aws_s3_bucket" "kops_state" {
  bucket        = local.kops_state_bucket_name
  force_destroy = true
  tags          = "${merge(local.tags)}"
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = aws_s3_bucket.kops_state.bucket
  acl    = "public-read-write"
}