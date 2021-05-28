# Deploy Python Falcon in AWS Lambda

##### 1. create the lambda handler
Create a [Falcon](https://falcon.readthedocs.io/en/stable/) API in `service.py`,
```py
# service.py
class QuoteResource:
    def on_get(self, req, resp):
        quote = {
            'quote': "Blabetiblou",
            'author': 'Raphaël JOIE'
        }

        resp.media = quote

api = falcon.App()
api.add_route('/quote', QuoteResource())
```
```
# requirements.txt
falcon
```
and import the API in a `lambda_function.py` file
```py
# lambda_function.py

from service import api
from python_falcon_lambda import lambda_handler

lambda_handler = lambda_handler(api)
```

##### 2. Build the lambda zip
Run [Python Lambda Builder](https://github.com/raphaeljoie/python-lambda-builder) to package
```shell
$ docker run \
    --volume $(pwd):/workdir \
    --platform linux/amd64 \
    raphaeljoie/python-lambda-builder \
    ".terraform/*"
```
to generate `build/lambda.zip`

##### 3. Deploy
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
}

output "api_url" {
  value = module.api.api_url
}
```
and `terraform apply`

## TODO
* Docker builder is using python3.8 => should use the same for lambda runner
