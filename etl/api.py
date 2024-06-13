#!/usr/bin/env python

import argparse
import flask

from dotenv import dotenv_values

from mxl_compiler.compiler import MXLCompiler


app = flask.Flask(__name__)
env = dotenv_values('.env')


@app.route('/compile-mxl', methods=['POST'])
def run():
    # check arguments
    if 'file' not in flask.request.files:
        return { 'result': 400, 'message': 'Missing <file>.' }
    # compile file
    try:
        file = flask.request.files['file']
        parts = MXLCompiler.from_file(file).compile()
        return {
            'success': 200,
            'parts': {
                part['id']: {
                    'name': part['name'],
                    'notes': part['obj'].to_json()
                }
                for part in parts
            }
        }
    except:
        return { 'result': 400, 'message': 'Failed to compile <file>.' }

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-d', '--debug', help='run the app in debug mode', action='store_true')
    args = arg_parser.parse_args()

    app.run(host='0.0.0.0', port=env['PORT'], debug=args.debug)
