sudo yum install bind -y

sudo cat > /tmp/named.conf << EndOFNamedConfOptions

acl whitelist {
    $CLIENT_WHITELIST;
    localhost;
    localnets;
};

options {
        listen-on port 53 { any; };
        listen-on-v6 port 53 {any; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        recursing-file  "/var/named/data/named.recursing";
        secroots-file   "/var/named/data/named.secroots";
        allow-query     { whitelist; };

        forwarders {
            168.63.129.16; # This is the well-known standard IP in Azure
        };
        forward only;

        recursion yes;

        dnssec-enable yes;
        dnssec-validation yes;

        auth-nxdomain no; # conform to RFC1035

        /* Path to ISC DLV key */
        bindkeys-file "/etc/named.iscdlv.key";

        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

EndOFNamedConfOptions

sudo cp /tmp/named.conf /etc/named.conf

sudo systemctl enable named.service
sudo systemctl restart named.service
