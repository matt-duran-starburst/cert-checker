#!/bin/bash

# Function to check if a file exists and is readable
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: File '$1' does not exist."
        return 1
    elif [ ! -r "$1" ]; then
        echo "Error: File '$1' is not readable."
        return 1
    fi
    return 0
}

# Function to extract certificates from a file
extract_certs() {
    local file="$1"
    local certs

    # Try to extract certificates using keytool (for Java keystore files)
    certs=$(keytool -list -v -keystore "$file" -storepass changeit 2>/dev/null | grep -E "Alias name:|Serial number:" | sed 'N;s/\n/ /')
    
    # If keytool doesn't work, try openssl (for PEM files)
    if [ -z "$certs" ]; then
        certs=$(openssl x509 -in "$file" -noout -subject -serial 2>/dev/null | tr '\n' ' ')
    fi

    # If still empty, the file might not contain valid certificates
    if [ -z "$certs" ]; then
        echo "Error: No valid certificates found in '$file'."
        return 1
    fi

    echo "$certs"
}

# Function to compare two cacert files
compare_certs() {
    file1="$1"
    file2="$2"
    
    # Check if both files exist and are readable
    check_file "$file1" || return 1
    check_file "$file2" || return 1
    
    certs1=$(extract_certs "$file1")
    if [ $? -ne 0 ]; then
        echo "$certs1"
        return 1
    fi

    certs2=$(extract_certs "$file2")
    if [ $? -ne 0 ]; then
        echo "$certs2"
        return 1
    fi
    
    echo "Certificates in $file1 but not in $file2:"
    comm -23 <(echo "$certs1" | sort) <(echo "$certs2" | sort)
    
    echo -e "\nCertificates in $file2 but not in $file1:"
    comm -13 <(echo "$certs1" | sort) <(echo "$certs2" | sort)
}

# Function to parse URL
parse_url() {
    local url="$1"
    local protocol=$(echo "$url" | grep :// | sed -e's,^\(.*://\).*,\1,g')
    local hostport="${url##$protocol}"
    local host="${hostport%%/*}"
    local port

    if [[ $host == *:* ]]; then
        port="${host#*:}"
        host="${host%:*}"
    else
        if [[ "$protocol" == "https://" ]]; then
            port=443
        elif [[ "$protocol" == "http://" ]]; then
            port=80
        else
            # Default to HTTPS if no protocol is specified
            port=443
        fi
    fi
    
    echo "$host $port"
}

# Function to check certificate against a URL
check_cert_url() {
    cacert="$1"
    url="$2"
    
    # Check if the cacert file exists and is readable
    check_file "$cacert" || return 1
    
    # Validate that the file contains certificates
    extract_certs "$cacert" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Error: No valid certificates found in '$cacert'."
        return 1
    fi
    
    # Parse URL
    read -r host port < <(parse_url "$url")
    
    if [ -z "$host" ]; then
        echo "Error: Invalid URL format. Please use 'http://hostname[:port]' or 'https://hostname[:port]'"
        return 1
    fi
    
    echo "Connecting to $host on port $port"
    
    # Run openssl command and capture both stdout and stderr
    result=$(openssl s_client -connect "${host}:${port}" -CAfile "$cacert" </dev/null 2>&1)
    
    if echo "$result" | grep -q "Verify return code: 0 (ok)"; then
        echo "Connection successful. Certificate used:"
        echo "$result" | openssl x509 -noout -subject -issuer
    else
        echo "Connection failed. Error:"
        if echo "$result" | grep -q "no certificate or crl found"; then
            echo "The certificate file appears to be empty or in an incorrect format."
            echo "Please check the content of '$cacert'"
        elif echo "$result" | grep -q "Connection refused"; then
            echo "Connection refused. The server may not be running or the port may be closed."
        elif echo "$result" | grep -q "gethostbyname failure"; then
            echo "Unable to resolve the hostname. Please check the URL."
        else
            echo "$result" | grep -E "verify error|unable to get local issuer certificate"
        fi
        echo -e "\nReceived certificate:"
        received_cert=$(echo "$result" | openssl x509 -noout -subject -issuer 2>/dev/null)
        if [ -n "$received_cert" ]; then
            echo "$received_cert"
        else
            echo "No valid certificate received or unable to parse the received certificate."
        fi
    fi
    
    # Display the full SSL/TLS handshake for debugging
    #echo -e "\nFull SSL/TLS handshake (for debugging):"
    #echo "$result"
}

# Main script
if [ "$1" = "compare" ] && [ $# -eq 3 ]; then
    compare_certs "$2" "$3"
elif [ "$1" = "check" ] && [ $# -eq 3 ]; then
    check_cert_url "$2" "$3"
else
    echo "Usage:"
    echo "  $0 compare <cacert1> <cacert2>"
    echo "  $0 check <cacert> <url>"
    echo "  Note: URL should be in the format 'http://hostname[:port]' or 'https://hostname[:port]'"
    echo "        If port is omitted, it defaults to 443 for HTTPS and 80 for HTTP"
    exit 1
fi