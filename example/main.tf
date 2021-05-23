provider "aws" {
  region = "eu-west-1"
}

variable "lambda_version" {
  type = string
}

resource "aws_s3_bucket" "bucket" {
  bucket = "r-lambda-functions"
}


module "api" {
  source = "../terraform"

  lambda_iam_role   = "terraform2-lambda-role"
  lambda_iam_policy = "terraform2-lambda-policy"

  lambda_bucket_name = aws_s3_bucket.bucket.bucket
  lambda_version = var.lambda_version

  lambda_name   = "terraform2-test"
  lambda_folder = "./"

  api_name = "terraform2-api"
  api_endpoints = [
    {
      name = "car",
      path = "car",
      method = ["GET", "POST"],
      parent = "root"
    },
    {
      name = "car-id",
      path = "{id}",
      method = ["GET"],
      parent = "car"
    },
    {
      name = "bike",
      path = "bike",
      method = ["PUT"],
      parent = "root"
    },
    {
      name = "bike-id",
      path = "{id}",
      method = ["GET", "POST", "PUT"],
      parent = "bike"
    }
  ]

  api_stage_name = ["dev", "prod"]
}

output "api_url" {
  value = module.api.api_url
}
