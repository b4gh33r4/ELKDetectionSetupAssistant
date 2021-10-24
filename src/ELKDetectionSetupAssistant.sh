#!/bin/bash

if [ ! $UID -eq 0 ]; then
    echo "[*] Run as root"
    exit 1
fi

echo "[*] Executing preliminary activities..."

ELKHOST="elk01"
ELKDOMAIN="domain.local"
LOGSTASHSSLFOLDER="/etc/logstash/ssl/"
ELASTICSSLFOLDER="/etc/elasticsearch/ssl/"
KIBANABASEURL="https://${ELKHOST}.${ELKDOMAIN}:5601/"
KIBANASSLFOLDER="/etc/kibana/ssl/"
WORKINGPATH="/tmp/"
CAFILE="${WORKINGPATH}elastic-stack-ca"
CERTFILE="${WORKINGPATH}elastic-stack-cert"
PASSFILE="${WORKINGPATH}elastic-stack-pass.txt"

echo "[*] Installing prerequisites..."

apt update && \
apt install openjdk-8-jdk unzip apt-transport-https -y

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

echo "[*] Installing ELK..."

apt update && \
apt install elasticsearch -y && \
apt install kibana -y && \
apt install logstash -y

systemctl enable elasticsearch
systemctl enable kibana
systemctl enable logstash

echo "[*] Configuring firewall..."

ufw allow 5601/tcp
ufw allow 5044/tcp

sleep 0.5

mkdir "${LOGSTASHSSLFOLDER}"
mkdir "${ELASTICSSLFOLDER}"
mkdir "${KIBANASSLFOLDER}"

echo "[*] Setting up hosts file..."

echo "127.0.0.1 localhost" > /etc/hosts
echo "127.0.0.1 ${ELKHOST}.${ELKDOMAIN} ${ELKHOST}" >> /etc/hosts

echo "[*] Generating SSL CA..."

# GENERATING SSL CA AND CERTS
/usr/share/elasticsearch/bin/elasticsearch-certutil ca \
    --out "${CAFILE}.zip" \
    --pem \
    --silent

sleep 1

unzip -o "${CAFILE}.zip" -d "${ELASTICSSLFOLDER}"
unzip -o "${CAFILE}.zip" -d "${LOGSTASHSSLFOLDER}"
unzip -o "${CAFILE}.zip" -d "${KIBANASSLFOLDER}"

sleep 1

echo "[*] Generating SSL Certs..."

# PEM FORMAT
/usr/share/elasticsearch/bin/elasticsearch-certutil cert \
    --ca-cert "${ELASTICSSLFOLDER}ca/ca.crt" \
    --ca-key "${ELASTICSSLFOLDER}ca/ca.key" \
    --ca-pass "" \
    --days 1825 \
    --name "${ELKHOST}.${ELKDOMAIN}" \
    --dns "*.${ELKDOMAIN}" \
    --ip "" \
    --out "${CERTFILE}.zip" \
    --pem \
    --silent

sleep 1

unzip -o "${CERTFILE}.zip" -d "${ELASTICSSLFOLDER}"
unzip -o "${CERTFILE}.zip" -d "${KIBANASSLFOLDER}"

sleep 1

echo "[*] Setting up Elasticsearch config (part 1)..."

echo "###############################################################################" >> /etc/elasticsearch/elasticsearch.yml
echo "#          Custom configuration begins below: Do not edit manually.           #" >> /etc/elasticsearch/elasticsearch.yml
echo "###############################################################################" >> /etc/elasticsearch/elasticsearch.yml
echo "discovery.type: single-node" >> /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.enabled: true" >> /etc/elasticsearch/elasticsearch.yml

sleep 0.5

echo "[*] Generating ELK system users passwords..."

# NOTE: It seems that elasticsearch-setup-passwords is able to reach elasticsearch only when ssl is not
# active so it is necessary to split the elasticsearch configuration in two parts with a service restart
# between them.
systemctl restart elasticsearch && \
/usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto --batch | tee "${PASSFILE}"

echo "[*] Setting up Elasticsearch config (part 2)..."

echo "xpack.security.http.ssl.enabled: true" >> /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.http.ssl.key: \"${ELASTICSSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.key\"" >> /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.http.ssl.certificate: \"${ELASTICSSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.crt\"" >> /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.http.ssl.certificate_authorities: \"${ELASTICSSLFOLDER}ca/ca.crt\"" >> /etc/elasticsearch/elasticsearch.yml
echo "###############################################################################" >> /etc/elasticsearch/elasticsearch.yml

systemctl restart elasticsearch

echo "[*] Setting up Kibana config..."

KIBANAPASS=$(cat ${PASSFILE} | grep -v -i changed | grep -i kibana_system | cut -d' ' -f4)
KIBANAKEY=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1)

echo "###############################################################################" >> /etc/kibana/kibana.yml
echo "#          Custom configuration begins below: Do not edit manually.           #" >> /etc/kibana/kibana.yml
echo "###############################################################################" >> /etc/kibana/kibana.yml
echo "server.host: \"0.0.0.0\"" >> /etc/kibana/kibana.yml
echo "server.name: \"${ELKHOST}\"" >> /etc/kibana/kibana.yml
echo "server.publicBaseUrl: \"${KIBANABASEURL}\"" >> /etc/kibana/kibana.yml
echo "elasticsearch.hosts: [ \"https://${ELKHOST}.${ELKDOMAIN}:9200\" ]" >> /etc/kibana/kibana.yml
echo "elasticsearch.ssl.certificateAuthorities: [ \"${KIBANASSLFOLDER}ca/ca.crt\" ]" >> /etc/kibana/kibana.yml
echo "elasticsearch.username: \"kibana_system\"" >> /etc/kibana/kibana.yml
echo "elasticsearch.password: \"${KIBANAPASS}\"" >> /etc/kibana/kibana.yml
echo "xpack.encryptedSavedObjects.encryptionKey: \"${KIBANAKEY}\"" >> /etc/kibana/kibana.yml
echo "server.ssl.enabled: true" >> /etc/kibana/kibana.yml
echo "server.ssl.certificate: \"${KIBANASSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.crt\"" >> /etc/kibana/kibana.yml
echo "server.ssl.key: \"${KIBANASSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.key\"" >> /etc/kibana/kibana.yml
echo "###############################################################################" >> /etc/kibana/kibana.yml

systemctl restart kibana

echo "[*] Setting up Logstash config..."

ELASTICUSER="elastic"
ELASTICPASS=$(cat ${PASSFILE} | grep -v -i changed | grep -i elastic | cut -d' ' -f4)
LOGSTASHPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

sleep 1.5

LOGSTASHROLE=$(curl -k -s -X POST "https://${ELASTICUSER}:${ELASTICPASS}@${ELKHOST}.${ELKDOMAIN}:9200/_xpack/security/role/logstash_writer" -H 'Content-Type: application/json' \
-d"{\"cluster\":[\"manage_index_templates\",\"monitor\",\"manage_ilm\"],\"indices\":[{\"names\":[\"*\"],\"privileges\":[\"write\",\"create\",\"delete\",\"create_index\",\"manage\",\"manage_ilm\"]}]}")

LOGSTASHUSER=$(curl -k -s -X POST "https://${ELASTICUSER}:${ELASTICPASS}@${ELKHOST}.${ELKDOMAIN}:9200/_xpack/security/user/logstash_internal" -H 'Content-Type: application/json' \
-d"{\"password\":\"${LOGSTASHPASS}\",\"roles\":[\"logstash_writer\"],\"full_name\":\"Internal Logstash User\"}")

if [[ ( -z $(echo $LOGSTASHROLE | grep created | grep true) ) || ( -z $(echo $LOGSTASHUSER | grep created | grep true) ) ]]; then
    echo "[!] Error creating Logstash user or role, please check Logstash status manually."
else
    echo "[*] Setting up Logstash pipelines..."

    read -r -d '' INPUT_0000 << EOM
input {
  beats {
    port => 5044
    tags => [ "beats" ]
  }
}
EOM
    echo "${INPUT_0000}" > "/etc/logstash/conf.d/0000-input-beats.conf"

    read -r -d '' FILTER_5000 << EOM
filter {
  mutate {
    split => ["[host][name]", "."]
  }
  mutate {
    replace => ["[host][name]", "%{[host][name][0]}"]
  }
}
EOM
    echo "${FILTER_5000}" > "/etc/logstash/conf.d/5000-filter-beats.conf"

    read -r -d '' OUTPUT_9000 << EOM
output {
  if "beats" in [tags] {
    if [@metadata][pipeline] {
      elasticsearch {
        hosts => ["https://${ELKHOST}.${ELKDOMAIN}:9200"]
        index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
        user => "logstash_internal"
        password => "${LOGSTASHPASS}"
        cacert => "${LOGSTASHSSLFOLDER}ca/ca.crt"
        pipeline => "%{[@metadata][pipeline]}"
      }
    } else {
      elasticsearch {
        hosts => ["https://${ELKHOST}.${ELKDOMAIN}:9200"]
        index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
        user => "logstash_internal"
        password => "${LOGSTASHPASS}"
        cacert => "${LOGSTASHSSLFOLDER}ca/ca.crt"
      }
    }
  }
}
EOM
    echo "${OUTPUT_9000}" > "/etc/logstash/conf.d/9000-output-beats.conf"

    systemctl restart logstash
fi

echo "[*] Cleaning up working path..."

rm -rf ${WORKINGPATH}elastic-stack-c*

echo "[!] Completed."
