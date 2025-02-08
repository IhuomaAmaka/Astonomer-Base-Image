#!/usr/bin/env python3

import json
import os
import sys

from airflow_models import Variable

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f'usage:\n\t {sys.argv[0]} <path to airflow variables json file>')

    json_file_path = sys.argv[1]

    with open(json_file_path) as json_file:
        json_str = json_file.read()

        #evaluate embedded env vars
        json_str = os.path.expandvars(json_str)
        dictionary = json.loads(json_str)

        for key in dictionary:
            Variable.set(key, dictionary[key])