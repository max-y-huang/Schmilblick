#!/usr/bin/env python

import argparse
import dotenv
import flask
import re
import urllib.request
import requests

from mxl_compiler.compiler import MXLCompiler


app = flask.Flask(__name__)
env = dotenv.dotenv_values('.env')


class URLOpener(urllib.request.FancyURLopener):
    version = "Mozilla/5.0"


@app.route('/compile-mxl', methods=['POST'])
def compile_mxl():
    # check arguments
    if 'file' not in flask.request.files:
        return { 'message': 'Missing <file>.' }, 400
    # compile file
    try:
        file = flask.request.files['file']
        parts = MXLCompiler.from_file(file).compile()
        return {
            'parts': {
                part['id']: {
                    'name': part['name'],
                    'notes': part['obj'].to_json()
                }
                for part in parts
            }
        }, 200
    except:
        return { 'message': 'Failed to compile <file>.' }, 400


@app.route('/scrape-mxl', methods=['POST'])
def scrape_mxl():
    
    with URLOpener().open(flask.request.args['url']) as f:
        html = f.read().decode('utf8')

    x = re.search('https:\/\/musescore\.com\/score\/download\/index\?score_id=(\d+)&amp;type=mxl&amp;h=(\d+)', html)
    x = re.sub('&amp;', '&', x.group())

    y = requests.get(x)
    with open('temp.mxl', 'wb') as f:
        f.write(y.content)
    return x


if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-d', '--debug', help='run the app in debug mode', action='store_true')
    args = arg_parser.parse_args()

    app.run(host='0.0.0.0', port=env['PYTHON_PORT'], debug=args.debug)
