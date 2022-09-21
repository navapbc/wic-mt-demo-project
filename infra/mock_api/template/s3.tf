# bucket for generated csv files
resource "aws_s3_bucket" "wic-mt-csv-files" {
  bucket        = "${var.environment_name}-api-csv-bucket"
  force_destroy = true
}
# encrypt data
resource "aws_s3_bucket_server_side_encryption_configuration" "wic-mt-csv-files" {
  bucket = aws_s3_bucket.wic-mt-csv-files.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# block public access
resource "aws_s3_bucket_public_access_block" "wic-mt-csv-files" {
  bucket = aws_s3_bucket.wic-mt-csv-files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# create iam policy for bucket
data "aws_iam_policy_document" "wic-mt-csv-files" {
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [aws_s3_bucket.wic-mt-csv-files.arn, "${aws_s3_bucket.wic-mt-csv-files.arn}/*"]
  }
}

# add policy to bucket
resource "aws_s3_bucket_policy" "wic-mt-csv-files" {
  bucket = aws_s3_bucket.wic-mt-csv-files.id
  policy = data.aws_iam_policy_document.wic-mt-csv-files.json
}

# enable bucket ownership controls: https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html
resource "aws_s3_bucket_ownership_controls" "wic-mt-csv-files" {
  bucket = aws_s3_bucket.wic-mt-csv-files.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
