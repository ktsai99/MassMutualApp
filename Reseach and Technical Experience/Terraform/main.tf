##########################################
#
# Basic Network Configurations
#
##########################################

provider "aws" {
  region = var.region
}

locals {
  s3_bucket = "${var.bucket_prefix}.${var.application_domain}"
  s3_origin_id = "s3-${var.bucket_prefix}.${var.application_domain}"
  route53_endpoint = var.environment != null && var.environment != "prod" ? "static-${var.environment}.${var.application_domain}" : "static.${var.application_domain}"
}

##########################################
#
# S3 Configurations
#
##########################################


resource "aws_s3_bucket" "this" {
  bucket = local.s3_bucket
  acl    = "public-read"

  cors_rule {
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    max_age_seconds = 3000
  }

  tags = {
    Name = local.s3_bucket
    env = var.environment
    product = "tcr"
    service = "static"
    team-contact = "infra_alert@campaignregistry.com"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            Effect: "Allow",
            Principal: {
                AWS: "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.this.id}"
            },
            Action: "s3:GetObject",
            Resource: "arn:aws:s3:::${local.s3_bucket}/*"
        }
    ]
  })
}

##########################################
#
# SSL Cert Configurations
#
##########################################


data "aws_acm_certificate" "selected" {
  domain      = var.environment == "demo" ? "*.campaignregistry.com" : local.route53_endpoint
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

##########################################
#
# Cloudfront Configurations
#
##########################################

resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "${local.s3_origin_id}"
}

resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true

  aliases = [local.route53_endpoint]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress = true
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = local.route53_endpoint
    env = var.environment
    product = "tcr"
    service = "static"
    team-contact = "infra_alert@campaignregistry.com"
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.selected.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }


}

##########################################
#
# Route53 DNS Configurations
#
##########################################


data "aws_route53_zone" "selected" {
  name         = "${var.application_domain}."
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.route53_endpoint
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
