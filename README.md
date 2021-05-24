# Deploy Python Falcon in AWS Lambda

##### 1. create the lambda handler
Create a python-falcon API in `service.py` as usual, and import it in a `lambda_function.py` file
```py
# lambda_function.py

from service import api
from python_falcon_lambda import lambda_handler

lambda_handler = lambda_handler(api)
```

##### 2. Build dependencies for AWS Lambda runner
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
It will generate a `build/package` directory with all the dependencies built for the AWS Lambda runner.

##### 3. Build package
Build a `build/lambda.zip` archive with the content of the 
```shell
# Append dependencies to zip archive. 
# Move to the directory is required to avoid the creation of 
# a root directory in archive
$ cd build/packages
$ zip -r ../../build/lambda.zip *
# Move back to project and append the required files to the archive
$ cd ../..
$ zip -r build/lambda.zip * \
    -x "venv/*" "__pycache__/*" "bin/*" ".idea/*" "build/*" ".terraform/*"
$ zip -r build/lambda.zip lambda_function.py
```

##### 4. Deploy
Prepare the deployment
```tf
provider "aws" {
  region = "eu-west-1"
}

module "api" {
  source = "git:///python-falcon-lambda/terraform"

  lambda_bucket_name = "shared-lambda-bucket-name"
  lambda_name = "my-lambda"
  lambda_version = "v0.1.0"
  lambda_folder = "./"
}

output "api_url" {
  value = module.api.api_url
}
```
and `terraform apply`

## TODO
* Docker builder is using python3.8 => should use the same for lambda runner
