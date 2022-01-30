from cmath import e
from logging import exception
import os, subprocess, re
from sys import stderr, stdout

regex = 'charset='

def change(ruta):
    for path, subPath, fileList in os.walk(ruta):
        for file in fileList:
            if(file != 'main.py'):
                full_path_file = '{0}/{1}'.format(path,file)
                process = subprocess.Popen(['file', '-i', full_path_file],
                                            stdout=subprocess.PIPE,
                                            stderr=subprocess.PIPE)

                stdout, stderr = process.communicate()
                stdout = stdout.decode('utf-8')
                charset = stdout[stdout.find(regex)::].strip()
                index = stdout.find(regex)
                charset = charset[charset.find('=')+1::].upper()
                if (charset != 'UTF-8'):
                    try:
                        print('***** CONVIRTIENDO ARCHIVO: {0} ***** CON ENCODING: {1}'.format(full_path_file, charset))
                        os.system('iconv -f {0} -t UTF-8//TRANSLIT "{1}" -o "{1}"'.format(charset,full_path_file))
                    except(e):
                        print(e)