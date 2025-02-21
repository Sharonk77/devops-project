# secrets
variable "aws_account_id" {
  type      = string
  sensitive = true
}

variable "bucket_name" {
  type      = string
  sensitive = true
}

variable "be_bucket_name" {
  type      = string
}

# backend state
terraform {
  backend "s3" {}
}

# remote state
data "terraform_remote_state" "backend_state" {
  backend = "s3"

  config = {
    bucket         = "terraform-tf-state-g5rx8pf3asnevz4h2djtmc"
    key            = "backend/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
  }
}

provider "aws" {
  region = "us-east-1"
}

# S3 bucket
resource "aws_s3_bucket" "health-check-web-bucket" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = false
  }
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "health-check-web-bucket" {
  bucket = aws_s3_bucket.health-check-web-bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "health-check-web-bucket-block" {
  bucket                  = aws_s3_bucket.health-check-web-bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.health-check-web-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.health-check-web-bucket.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::${aws_s3_bucket.health-check-web-bucket.id}/*",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" : "arn:aws:cloudfront::${var.aws_account_id}:distribution/${aws_cloudfront_distribution.s3_distribution.id}"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${var.aws_account_id}:root"
        },
        "Action" : "s3:*",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.health-check-web-bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.health-check-web-bucket.id}/*"
        ]
      }

    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.health-check-web-bucket-block]
}

# CloudFront
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-oac"
  description                       = "OAC for S3 health-check web bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.health-check-web-bucket.bucket_regional_domain_name
    origin_id   = "health-check-web-bucket"

    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  enabled = true
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "health-check-web-bucket"
    viewer_protocol_policy = "allow-all"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_root_object = "index.html"

}


