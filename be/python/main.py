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

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-d', '--debug', help='run the app in debug mode', action='store_true')
    args = arg_parser.parse_args()

    app.run(host='0.0.0.0', port=env['PYTHON_PORT'], debug=args.debug)
