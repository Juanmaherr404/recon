#!/bin/bash
./reset.sh
figlet -f slant suprimoware
if [ -z "$1" ]; then

    echo "Error: NO enviaste un dominio"
    echo "Uso: ./main.sh <dominio>"
    exit 1
fi

dominio=$1
echo "Escaneando $dominio"

#Estructura de carpetas

timestamp=$(date +"%Y-%m-%d_%H:%M:%S")
ruta_resultados=./resultados/$dominio/$timestamp
mkdir -p "$ruta_resultados" 
mkdir -p "$ruta_resultados/raw" 
mkdir -p "$ruta_resultados/clean" 

#Analisis de infraestructura

dig +short A $dominio > $ruta_resultados/clean/IP
dig +short MX $dominio > $ruta_resultados/clean/MX
dig +short TXT $dominio > $ruta_resultados/clean/TXT
dig +short NS $dominio > $ruta_resultados/clean/NS
dig +short SRV $dominio > $ruta_resultados/clean/SRV
dig +short AAAA $dominio > $ruta_resultados/clean/AAAA
dig +short CNAME $dominio > $ruta_resultados/clean/CNAME
dig +short SOA $dominio > $ruta_resultados/clean/SOA

echo "Extrayendo rangos de IP"
#whois -b $(cat $ruta_resultados/clean/IP) | grep 'inetnum' | awk '{print $2, $3, $4}' > $ruta_resultados/output/rangos_ripe

whois $dominio > $ruta_resultados/raw/whois
echo "Realizado whois"
dig $dominio > $ruta_resultados/raw/dig
echo "Realizado dig"

curl -sI https://$dominio > $ruta_resultados/raw/headers
cat $ruta_resultados/raw/headers | grep -i "server" | awk '{print $2}' > $ruta_resultados/clean/header_server
echo "Realizado los header"

while IFS= read -r ip; do
    whois -b "$ip" | grep 'inetnum' | awk '{print $2, $3, $4}' >> $ruta_resultados/clean/rangos_ripe
done < $ruta_resultados/clean/IP
echo "Extrayendo rango de IP"

# Revisar y eliminar archivos vacíos en la carpeta /clean
for file in "$ruta_resultados/clean"/*; do
  if [ ! -s "$file" ]; then
    echo "Eliminando archivo vacío: $file"
    rm "$file"
  fi
done