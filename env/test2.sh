#!/bin/bash

#Leer cada línea del archivo domains

while IFS= read -r domain; do

    python scrapping-asn.py --input "$domain" --output "output/"

done < domains_definitive