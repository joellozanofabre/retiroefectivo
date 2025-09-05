import csv
import urllib.request
import tempfile
import os

# Descargar el archivo desde Google Drive
file_id = '1dZ5i3xysuRZ3iH9q7DttQPGCoaZFnBIP'
url = f'https://drive.google.com/uc?export=download&id={file_id}'

# Descargar a un archivo temporal
with tempfile.NamedTemporaryFile(delete=False, suffix='.csv') as tmp_file:
    with urllib.request.urlopen(url) as response:
        content = response.read()
        tmp_file.write(content)
    csv_file_path = tmp_file.name

# Leer el CSV y generar INSERTs
output_file = 'inserts_cl_ente.sql'

# Definir qué posiciones son campos numéricos (basado en la estructura de la tabla)
# Estas son las posiciones (índices) de los campos que deben ser numéricos
posiciones_numericas = [
    0,   # en_ente (int)
    3,   # en_filial (tinyint)
    4,   # en_oficina (smallint)
    5,   # en_ced_ruc (numeric)
    9,   # en_direccion (smallint)
    10,  # en_referencia (tinyint)
    11,  # en_casilla (tinyint)
    14,  # en_balance (smallint)
    15,  # en_grupo (int)
    16,  # en_pais (smallint)
    17,  # en_oficial (smallint)
    21,  # en_cont_malas (smallint)
    24,  # en_patrimonio_tec (money)
    29,  # c_rep_legal (int)
    30,  # c_activo (money)
    31,  # c_pasivo (money)
    33,  # c_capital_social (money)
    34,  # c_reserva_legal (money)
    37,  # c_plazo (tinyint)
    39,  # c_direccion_domicilio (tinyint)
    43,  # c_rep_jud (int)
    44,  # c_rep_ex_jud (int)
    46,  # c_capital_inicial (money)
    47,  # c_num_acciones (int)
    48,  # c_cap_pagado (money)
    62,  # p_num_cargas (tinyint)
    63,  # p_nivel_ing (money)
    64,  # p_nivel_egr (money)
    66,  # p_personal (tinyint)
    67,  # p_propiedad (tinyint)
    68,  # p_trabajo (tinyint)
    69,  # p_soc_hecho (tinyint)
    72,  # en_serv_adic (tinyint)
    77,  # p_dependientes (int)
    81,  # en_oficina_mod (smallint)
    89,  # en_pais_nac (smallint)
    93,  # en_segmento_negocio (int)
    95,  # en_glb_finance_cid (int)
    96,  # en_pais_residencia (smallint)
    97,  # en_base_number (int)
    98   # en_ciudad_nac (smallint)
]

# Posiciones de campos de fecha
posiciones_fecha = [
    6,   # en_fecha_crea
    7,   # en_fecha_mod
    35,  # c_fecha_const
    40,  # c_fecha_inscrp
    42,  # c_fecha_aum_capital
    59,  # p_fecha_nac
    70,  # p_fecha_ingreso
    71,  # p_fecha_expira
    74,  # p_fecha_emision_cedula
    75,  # p_fecha_expiracion_cedula
    85,  # p_fecha_emision_dui
    86,  # p_fecha_vencimiento_dui
    88   # en_fecha_act
]

with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
    # Usar punto y coma como delimitador
    csv_reader = csv.reader(csvfile, delimiter=';')
    
    with open(output_file, 'w', encoding='utf-8') as sqlfile:
        sqlfile.write("-- Script de INSERTs para tabla cl_ente\n")
        sqlfile.write("-- Generado automáticamente desde archivo CSV\n\n")
        
        for row_num, row in enumerate(csv_reader):
            values = []
            for i, value in enumerate(row):
                value = value.strip()
                
                if value == '':
                    values.append('NULL')
                else:
                    # Escapar comillas simples
                    escaped_value = value.replace("'", "''")
                    
                    if i in posiciones_numericas:
                        # Campo numérico - sin comillas
                        # Limpiar el valor para verificar si es numérico
                        clean_value = escaped_value.replace(',', '').replace('$', '').replace(' ', '')
                        if clean_value.replace('.', '', 1).replace('-', '', 1).isdigit():
                            values.append(clean_value)
                        else:
                            # Si no es numérico válido, tratar como texto entre comillas
                            values.append(f"'{escaped_value}'")
                    
                    elif i in posiciones_fecha:
                        # Campo de fecha - entre comillas
                        # Sybase generalmente acepta formatos como: 'Sep 30 2024 12:00:00:000AM'
                        values.append(f"'{escaped_value}'")
                    
                    else:
                        # Campo de texto - entre comillas
                        values.append(f"'{escaped_value}'")
            
            # Construir la sentencia INSERT
            insert_stmt = f"INSERT INTO dbo.cl_ente VALUES ({', '.join(values)});\n"
            sqlfile.write(insert_stmt)

# Limpiar archivo temporal
os.unlink(csv_file_path)

print(f"Script SQL generado: {output_file}")
print(f"Se procesaron {row_num + 1} registros")