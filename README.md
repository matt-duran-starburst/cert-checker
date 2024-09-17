# cert-checker
## Bash script to check validity of JKS and PEM truststore files

This bash script is capable of doing two things currently:
1) Comparing two certificate files (either .PEM or .JKS) against each other to see which certificates are included in both files. This is useful for if a customer is not sure which file is the correct one to be used

2) When given a certificate file and a domain, we can check the validity of the certificate against the domain in question. This is useful for intermittent SSL issues to check what the issuer of the certificate is.

# Usage:

./cacert_checker.sh check certfile https://example.com

Example output:

```
Example output of a failure:
Connecting to starburstdata.com on port 443
Connection failed. Error:
verify error:num=20:unable to get local issuer certificate
Verification error: unable to get local issuer certificate
Verify return code: 20 (unable to get local issuer certificate)
    Verify return code: 20 (unable to get local issuer certificate)

Received certificate:
subject=CN=blog.starburst.io
issuer=C=US, O=Let's Encrypt, CN=R11
```


./cacert_checker.sh compare certfile1 certfile2

Example output:

```
Enter pass phrase for PKCS12 import pass phrase:

Certificates in certfile1 but not in certfile2:
subject=CN=*.starburstdata.com serial=D8302BD28BFCB9FF

Certificates in certfile2 but not in certfile1:
subject=DC=net, DC=starburstdata, DC=fieldeng, DC=sa, CN=SUBORDINATECA-CA serial=7500000002E4A59F721D4A2A18000000000002
```