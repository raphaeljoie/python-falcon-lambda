provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "r-lambda-functions"
}


module "api" {
  source = "../terraform"

  lambda_bucket_name = aws_s3_bucket.bucket.bucket
  # Take the version from the VERSION file. Could be taken from git tag, or variable, or ...
  lambda_version = file("VERSION")
  lambda_name   = "w-store"
  lambda_folder = "./"

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
