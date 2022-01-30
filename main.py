from flask import Flask, render_template, request, jsonify
import flask
from flask.helpers import make_response
from buscaPalabras import BuscadorPalabras
import os


app = Flask('__name__')
app.secret_key = 'development key'


bp = BuscadorPalabras()


@app.route('/')
def index():
    return flask.render_template('index.html')

@app.route('/result', methods=['GET'])
def result():
    if request.method == 'GET':
        path = request.args.get('dir')
        path = path.replace('\\\\', '\\')
        lista = bp.recorreDir(path)
        resultado = lista
        return render_template('result.html', result=resultado)

@app.route('/archivo/<path:name>')
def archivo(name):
    expArch = open('palabras.txt')

    listaExp = list()
    for exp in expArch:
        listaExp.append(exp.replace('\n', ''))

    expArch.close()
    cont = bp.recorreArch(name)
    lista = bp.buscaCoincidencia(cont, listaExp)
    resultado = [name, lista]
    return render_template('archivo.html', result=resultado)

@app.route('/abrir/<path:name>')
def abrir(name):
    os.system('start notepad++ "{}"'.format(name))
    return name

if __name__ == '__main__':
    app.run(debug=True)