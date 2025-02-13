# secrets from github
variable "aws_account_id" {
  type      = string
  sensitive = true
}

variable "bucket_name" {
  type      = string
  sensitive = true
}

# backend
terraform {
  backend "s3" {}

}

provider "aws" {
  region = "us-east-1"
}

# S3 bucket creation
resource "aws_s3_bucket" "dummy_web_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_website_configuration" "dummy_web_bucket" {
  bucket = aws_s3_bucket.dummy_web_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "dummy_web_block" {
  bucket                  = aws_s3_bucket.dummy_web_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.dummy_web_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.dummy_web_bucket.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::${aws_s3_bucket.dummy_web_bucket.id}/*",
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
          "arn:aws:s3:::${aws_s3_bucket.dummy_web_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.dummy_web_bucket.id}/*"
        ]
      }

    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.dummy_web_block]
}

# CloudFront creation:
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-oac"
  description                       = "OAC for S3 bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.dummy_web_bucket.bucket_regional_domain_name
    origin_id   = "S3-dummy-web-bucket"

    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  enabled = true
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-dummy-web-bucket"
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


