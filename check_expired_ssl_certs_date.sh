mkdir /tmp/certs
cd /tmp/certs
awk 'BEGIN {c=0;} /BEGIN CERT/{c++} { print > "cert"c".crt"}' /etc/ssl/certs/ca-certificates.crt
mkdir -p expired_certs

for cert in cert*.crt; do
    exp_date=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
    exp_date_secs=$(date -d "$exp_date" +%s)
    now_secs=$(date +%s)
    if [ $now_secs -gt $exp_date_secs ]; then
        echo "$cert is expired (Expired on $exp_date)"
        mv "$cert" expired_certs/
    fi
done

cd expired_certs

for cert in *.crt; do
    echo "Issuer for $cert:"
    issuer_info=$(openssl x509 -in "$cert" -noout -issuer | sed -e 's/^issuer= //' -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')
    
    echo "Issuer: $issuer_info"  
    find /usr/share/ca-certificates /usr/local/share/ca-certificates -type f -name '*.crt' -exec sh -c '
        issuer="$1"
        shift  
        for c in "$@"; do  
            cert_issuer=$(openssl x509 -in "$c" -noout -issuer | sed -e "s/^issuer= //" -e "s/^[[:space:]]*//g" -e "s/[[:space:]]*$//g")
            if [ "$cert_issuer" = "$issuer" ]; then
                echo "Match found in: $c"
            fi
        done
    ' find-sh "$issuer_info" {} +
done
