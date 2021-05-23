# Deploy Python Falcon in AWS Lambda

##### 1. create the lambda handler
Create a python-falcon API in `service.py` as usual, and import it in a `lambda_function.py` file
```py
# lambda_function.py

from service import api
from python_falcon_lambda import lambda_handler

lambda_handler = lambda_handler(api)
```

##### 2. Build the lambda zip
Create the docker builder
```shell
$ cd python-falcon-lambda/builder && \
  docker buildx build \
    --platform linux/amd64 \
    --tag lambda-docker-builder . 
```
And build
```shell
# Move back to project root and ensure build directory
$ cd ../../ && mkdir build
$ # Actually build
$ docker run -v $(pwd):/workdir \
    --platform linux/amd64 lambda-docker-builder
```
It will generate a `build/lambda.zip` file

##### 3. Deploy
Prepare the deployment
```deployment.tf
provider "aws" {
  region = "eu-west-1"
}

variable "lambda_version" {
  type = string
}

module "api" {
  source = "git:///python-falcon-lambda/terraform"

  lambda_bucket_name = "bucket-name"
  lambda_version = var.lambda_version

  lambda_folder = "./"
}

output "api_url" {
  value = module.api.api_url
}
```
and `terraform apply`
