#### COMMON

variable "tags" {
  description = "Tags to add to all the taggable resources"
  type        = map(string)

  default = {
    iaac          = "true"
    iaac_language = "terraform"
  }
}


#### IAM for Lambda policies

variable "lambda_iam_role" {
  description = "Name of the IAM role used for the Lambda function"
  type        = string
  default     = "ApiLambdaRole"
}

variable "lambda_iam_policy" {
  description = "Name of the IAM policy used for the Lambda function"
  type        = string
  default     = "ApiLambdaPolicy"
}


#### S3 Bucket

variable "lambda_bucket_name" {
  description = "S3 Bucket name to store the lambda zip"
  type        = string
}

variable "lambda_version" {
  description = "function version"
  type        = string
}


#### Lambda function

variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "lambda-function"
}

variable "lambda_folder" {
  description = "Location of the lambda source code"
  type        = string
  default     = "./"
}

variable "lambda_runtime" {
  description = "python runtime used"
  type        = string

  default = "python3.8"
}

variable "lambda_handler" {
  description = "AWS Lambda python handler name"
  type        = string

  default = "lambda_function.lambda_handler"
}

variable "lambda_timeout" {
  description = "Timeout of the lambda"
  type        = number

  default = 10
}

variable "lambda_environment" {
  description = "Environment variables"
  type        = map(string)

  default = null
}


#### API Gateway

variable "api_name" {
  description = "A name for the API Gateway"
  type        = string
  default     = "api-gateway"
}

variable "api_endpoints" {
  description = "List of API Endpoints"
  type = list(object({
    name   = string,
    path   = string,
    method = list(string),
    parent = string
  }))
  default   = [
    {
      name = "proxy",
      path = "{proxy+}",
      method = ["GET", "POST", "PUT", "DELETE", "PATCH"],
      parent = "root"
    }
  ]
}

variable "api_stage_name" {
  description = "List of stages to deploy"
  type        = list(string)
  default     = ["dev"]
}
