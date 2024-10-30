#!/bin/bash

# Verificar que se ha proporcionado un dominio
if [ -z "$1" ]; then
    echo "Error: NO enviaste un dominio"
    echo "Uso: ./main.sh <dominio>"
    exit 1
fi

dominio=$1
echo "Escaneando $dominio"

# Crear la estructura de carpetas
timestamp=$(date +"%Y-%m-%d_%H:%M:%S")
ruta_resultados=./resultados/$dominio/$timestamp
mkdir -p "$ruta_resultados/raw" 
mkdir -p "$ruta_resultados/clean" 

# Ejecutar CTFR para encontrar subdominios y guardar los resultados en raw/subdominios.txt
echo "Ejecutando CTFR para encontrar subdominios..."
ctfr -d "$dominio" > "$ruta_resultados/raw/subdominios.txt" 2>&1
wait  # Esperar a que CTFR termine

# Limpiar subdominios en raw/subdominios.txt, dejando solo los válidos y ordenados en clean/subdominios.txt
grep -oP "([a-zA-Z0-9-]+\.)+$dominio" "$ruta_resultados/raw/subdominios.txt" |   # Extraer subdominios válidos
    grep -E "^[a-zA-Z0-9.-]+$" |           # Filtrar líneas con caracteres válidos
    grep -v "^$dominio$" |                 # Opcional: eliminar el dominio raíz (si no deseas incluirlo)
    sort -u > "$ruta_resultados/clean/subdominios.txt"

# Verificar si el archivo de subdominios contiene datos y agregar al archivo Markdown si es el caso
if [ -s "$ruta_resultados/clean/subdominios.txt" ]; then
    echo "Subdominios limpios guardados en $ruta_resultados/clean/subdominios.txt"
    echo "### Subdominios" >> "$archivo_md"
    cat "$ruta_resultados/clean/subdominios.txt" | awk '{print "- " $0}' >> "$archivo_md"
else
    echo "No se encontraron subdominios o CTFR falló."
fi


#Analisis de infraestructura

dig +short A $dominio > $ruta_resultados/clean/IP
dig +short MX $dominio > $ruta_resultados/clean/MX
dig +short TXT $dominio > $ruta_resultados/clean/TXT
dig +short NS $dominio > $ruta_resultados/clean/NS
dig +short SRV $dominio > $ruta_resultados/clean/SRV
dig +short AAAA $dominio > $ruta_resultados/clean/AAAA
dig +short CNAME $dominio > $ruta_resultados/clean/CNAME
dig +short SOA $dominio > $ruta_resultados/clean/SOA
dig +short txt _dmarc.$domain > $ruta_resultados/clean/TXT

# Realizar consultas WHOIS y DIG
whois "$dominio" > "$ruta_resultados/raw/whois"
echo "Realizado whois"
dig "$dominio" > "$ruta_resultados/raw/dig"
echo "Realizado dig"

# Obtener y guardar los headers HTTP
curl -sI "https://$dominio" > "$ruta_resultados/raw/headers"
grep -i "server" "$ruta_resultados/raw/headers" | awk '{print $2}' > "$ruta_resultados/clean/header_server"
echo "Realizado los headers"

# Extraer rangos de IP a partir de registros DNS
dig +short A "$dominio" > "$ruta_resultados/clean/IP"

# Extraer rangos de IP usando WHOIS
while IFS= read -r ip; do
    whois -b "$ip" | grep 'inetnum' | awk '{print $2, $3, $4}' >> "$ruta_resultados/clean/rangos_ripe"
done < "$ruta_resultados/clean/IP"
echo "Extrayendo rango de IP"

# Revisar y eliminar archivos vacíos en la carpeta /clean
for file in "$ruta_resultados/clean"/*; do
  if [ ! -s "$file" ]; then
    echo "Eliminando archivo vacío: $file"
    rm "$file"
  fi
done

# Generar el archivo Markdown con los resultados
archivo_md="/tmp/resultado.md"
echo "# $dominio" > "$archivo_md"
echo "## Infraestructura" >> "$archivo_md"

# Consultas y escritura condicional en el archivo
if ip=$(dig +short A "$dominio"); then
    # Listar todas las IPs
    [ -n "$ip" ] && echo "### IPs" >> "$archivo_md" && echo "$ip" | awk '{print "- " $0}' >> "$archivo_md"
fi

if aaaa=$(dig +short AAAA "$dominio"); then
    # Listar todas las IPs AAAA
    [ -n "$aaaa" ] && echo "### AAAA" >> "$archivo_md" && echo "$aaaa" | awk '{print "- " $0}' >> "$archivo_md"
fi

if mx=$(dig +short MX "$dominio"); then
    # Contar y verificar si hay más de un registro MX
    mx_count=$(echo "$mx" | wc -l)
    if [ "$mx_count" -gt 1 ]; then
        echo "### MX" >> "$archivo_md"
        echo "$mx" | awk '{print "- " $0}' >> "$archivo_md"
    elif [ "$mx_count" -eq 1 ]; then
        echo "### MX $mx" >> "$archivo_md"
    fi
fi

if txt=$(dig +short TXT "$dominio"); then
    # Contar y verificar si hay más de un registro TXT
    txt_count=$(echo "$txt" | wc -l)
    if [ "$txt_count" -gt 1 ]; then
        echo "### TXT" >> "$archivo_md"
        echo "$txt" | awk '{print "- " $0}' >> "$archivo_md"
    elif [ "$txt_count" -eq 1 ]; then
        echo "### TXT $txt" >> "$archivo_md"
    fi
fi

if ns=$(dig +short NS "$dominio"); then
    # Contar y verificar si hay más de un registro NS
    ns_count=$(echo "$ns" | wc -l)
    if [ "$ns_count" -gt 1 ]; then
        echo "### NS" >> "$archivo_md"
        echo "$ns" | awk '{print "- " $0}' >> "$archivo_md"
    elif [ "$ns_count" -eq 1 ]; then
        echo "### NS $ns" >> "$archivo_md"
    fi
fi

if srv=$(dig +short SRV "$dominio"); then
    # Contar y verificar si hay más de un registro SRV
    srv_count=$(echo "$srv" | wc -l)
    if [ "$srv_count" -gt 1 ]; then
        echo "### SRV" >> "$archivo_md"
        echo "$srv" | awk '{print "- " $0}' >> "$archivo_md"
    elif [ "$srv_count" -eq 1 ]; then
        echo "### SRV $srv" >> "$archivo_md"
    fi
fi

if cname=$(dig +short CNAME "$dominio"); then
    # Contar y verificar si hay más de un registro CNAME
    cname_count=$(echo "$cname" | wc -l)
    if [ "$cname_count" -gt 1 ]; then
        echo "### CNAME" >> "$archivo_md"
        echo "$cname" | awk '{print "- " $0}' >> "$archivo_md"
    elif [ "$cname_count" -eq 1 ]; then
        echo "### CNAME $cname" >> "$archivo_md"
    fi
fi

if soa=$(dig +short SOA "$dominio"); then
    # Contar y verificar si hay más de un registro SOA
    soa_count=$(echo "$soa" | wc -l)
    if [ "$soa_count" -gt 1 ]; then
        echo "### SOA" >> "$archivo_md"
        echo "$soa" | awk '{print "- " $0}' >> "$archivo_md"
    elif [ "$soa_count" -eq 1 ]; then
        echo "### SOA $soa" >> "$archivo_md"
    fi
fi

# Añadir encabezado del servidor si existe
if [ -s "$ruta_resultados/clean/header_server" ]; then
    server=$(cat "$ruta_resultados/clean/header_server")
    echo "### Servidores" >> "$archivo_md"
    echo "$server" | awk '{print "- " $0}' >> "$archivo_md"
fi

# Añadir ASN y rangos de IP si existen
echo "### ASN" >> "$archivo_md"
if [ -s "$ruta_resultados/clean/rangos_ripe" ]; then
    cat "$ruta_resultados/clean/rangos_ripe" | awk '{print "- " $0}' >> "$archivo_md"
else
    echo "- No encontrado" >> "$archivo_md"
fi

# Visualizar el archivo con markmap
markmap "$archivo_md"


ctfr -d $dominio 
katana -u $dominio