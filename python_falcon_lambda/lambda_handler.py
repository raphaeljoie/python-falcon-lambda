import re
import sys

from io import BytesIO
from urllib import parse


def lambda_handler(app, path_prefix='/'):
    def handler(event, context):
        resp = Response()

        output = app(
            Request(event, context, path_prefix),
            resp
        )

        return resp.build_lambda_response(output)
    return handler


class Response(object):
    def __init__(self):
        self.status = 500
        self.headers = []
        self.body = BytesIO()

    def __call__(self, status, headers, exc_info=None):
        self.status, *_ = status.split()
        self.headers = headers

        return self.body.write

    def build_lambda_response(self, wsgi_resp):
        body = ''.join(
            map(
                lambda s: s.decode('utf-8'),
                [self.body.getvalue()] + list(wsgi_resp)
            )
        )

        return {
            'statusCode': str(self.status),
            'headers': dict(self.headers),
            'body': body,
        }


class Request(dict):

    def __init__(self, event, context, path_prefix):
        super().__init__()

        body = (event.get('body') or '').encode('utf-8')
        headers = {
            key.upper().replace('-', '_'): val
            for key, val in (event.get('headers') or {}).items()
        }

        remote_addr, *_ = headers.get('X_FORWARDED_FOR', '127.0.0.1').partition(', ')
        path = event['path']
        path = re.sub(f'^{path_prefix}', '/', path)

        environ = {
            'SCRIPT_NAME': '',
            'REQUEST_METHOD': event['httpMethod'],
            'PATH_INFO': path,
            'QUERY_STRING': parse.urlencode(event['queryStringParameters'] or {},
                                            safe=','),
            'REMOTE_ADDR': remote_addr,
            'CONTENT_TYPE': headers.get('CONTENT_TYPE'),
            'CONTENT_LENGTH': str(len(body) or ''),
            'HTTP': 'on',
            'SERVER_NAME': headers.get('HOST'),
            'SERVER_PORT': headers.get('X_FORWARDED_PORT'),
            'SERVER_PROTOCOL': 'HTTP/1.1',
            'wsgi.version': (1, 0),
            'wsgi.input': BytesIO(body),
            'wsgi.errors': sys.stderr,
            'wsgi.multithread': False,
            'wsgi.multiprocess': False,
            'wsgi.run_once': False,
            'wsgi.url_scheme': headers.get('X_FORWARDED_PROTO'),
        }
        self.update(environ)

        # Push all headers in
        for name, val in headers.items():
            self[f'HTTP_{name}'] = val
