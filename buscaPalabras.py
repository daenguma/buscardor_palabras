import os
import re
import platform
from CambiadorDeEncoding import encoding_changer

myOS = platform.system()
barra = '\\'
if myOS == 'Linux':
    barra = '/'

class BuscadorPalabras(object):

    def __init__(self):
        self.fileName = ''

    def recorreDir(self, dir):
        listArch = list()
        encoding_changer.change(dir)
        for path, subPath, fileList in os.walk(dir):
            for file in fileList:
                dicc = {
                        'RUTA': path+barra+file,
                        'ARCHIVO': file
                        }
                listArch.append(dicc)
        return listArch

    def recorreArch(self, dir):
        l = list()
        contador = 0
        if (myOS == 'Linux'):
            arch = open('/'+dir,'r',encoding='utf-8')
        else:
            arch = open(dir,'r',encoding='utf-8')
        cont = arch.readlines()
        for linea in cont:
            contador = contador + 1
            obj = {'reg': linea, 'line':contador}
            l.append(obj)
        return l

    def setFileName(self, file):
        self.fileName = file

    def getFileName(self):
        return self.fileName

    def buscaCoincidencia(self, cont, lista):
        listaCoin = list()
        for exp in lista:
            for x in cont:
                x['reg'] = x['reg'].replace('\n', '')
                patron = re.compile(exp, re.I)
                exp = exp.replace('\n', '')
                if patron.search(x['reg']):
                    dicc = {
                        'EXPRESION': patron.pattern.replace('\\', '').upper(),
                        'REGISTRO': x['reg'].replace('\n', '').lower(),
                        'LINEA': x['line']
                    }
                    listaCoin.append(dicc)
        return listaCoin

