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

variable "lambda_iam_role_arn" {
  type = string
  default = null
}

variable "lambda_iam_role" {
  description = "Name of the IAM role used for the Lambda function"
  type        = string
  default     = null
}

#### S3 Bucket

variable "lambda_bucket_name" {
  description = "Name of the shared S3 bucked used to store the lambdas"
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

variable "vpc_security_group_ids" {
  description = "For network connectivity to AWS resources in a VPC, specify a list of security groups in the VPC. When you connect a function to a VPC, it can only access resources and the internet through that VPC."
  type = list(string)
  default = []
}

variable "vpc_subnet_ids" {
  description = "For network connectivity to AWS resources in a VPC, specify a list of subnets in the VPC. When you connect a function to a VPC, it can only access resources and the internet through that VPC."
  type = list(string)
  default = []
}

#### API Gateway

variable "api_name" {
  description = "A name for the API Gateway"
  type        = string
  default     = null
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
