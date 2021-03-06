#!/bin/bash

if [ ! $UID -eq 0 ]; then
  echo "[*] Run as root"
  exit 1
fi

ELKHOST="elk01"
ELKDOMAIN="domain.local"
ELASTICADDRESS="127.0.0.1"
ELASTICSSLFOLDER="/etc/elasticsearch/ssl/"
LOGSTASHSSLFOLDER="/etc/logstash/ssl/"
KIBANASSLFOLDER="/etc/kibana/ssl/"
KIBANABASEURL="https://${ELKHOST}.${ELKDOMAIN}:5601/"
WORKINGPATH="/tmp/"
CAWORKINGPATH="${WORKINGPATH}elastic-stack-ca/"
CERTWORKINGPATH="${WORKINGPATH}elastic-stack-cert/"
PASSFILE="${WORKINGPATH}elastic-stack-pass.txt"
VALIDATEIP="^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
VALIDATELINUXPATH="^/$|^(/[a-zA-Z0-9_-]+)+$"
SPLITROLES=1

function ShowHelp {
  echo '  _       _                               __                                               '
  echo ' |_ | |  | \  _ _|_  _   _ _|_ o  _  ._  (_   _ _|_     ._   /\   _  _ o  _ _|_  _. ._ _|_ '
  echo ' |_ | |< |_/ (/_ |_ (/_ (_  |_ | (_) | | __) (/_ |_ |_| |_) /--\ _> _> | _>  |_ (_| | | |_ '
  echo '                                                        |                                  '
  echo
  echo " usage: $0 OPTION [ARGS]"
  echo
  echo " OPTIONS:"
  echo
  echo "     elasticsearch          Install and configure Elasticsearch"
  echo "     kibana                 Install and configure Kibana"
  echo "     logstash               Install and configure Logstash"
  echo "     full                   Install and configure ELK"
  echo "     help                   Show this help"
  echo
  echo " ARGS:"
  echo
  echo " usage: $0 full"
  echo
  echo " usage: $0 elasticsearch"
  echo
  echo " usage: $0 kibana --kibana-user USERNAME --kibana-pass PASS [--elasticsearch-ip IPADDRESS | --ssl-path PATH]"
  echo
  echo "     --kibana-user          Kibana user"
  echo "     --kibana-pass          Kibana user password"
  echo "     --elasticsearch-ip     Elasticsearch node IP address"
  echo "                            NOTE: default value is 127.0.0.1"
  echo "     --ssl-path             Path where ssl CA and CERTS are placed"
  echo "                            NOTE: if omitted the ssl CA and CERTS are newly generated"
  echo
  echo " usage: $0 logstash --logstash-user USERNAME --logstash-pass PASS [--elasticsearch-ip IPADDRESS | --ssl-path PATH]"
  echo
  echo "     --logstash-user        Logstash user"
  echo "     --logstash-pass        Logstash user password"
  echo "     --elasticsearch-ip     Elasticsearch node IP address"
  echo "                            NOTE: default value is 127.0.0.1"
  echo "     --ssl-path             Path where ssl CA and CERTS are placed"
  echo "                            NOTE: if omitted the ssl CA and CERTS are newly generated"
  echo
}

function InstallDependency {
  echo "[*] Installing prerequisites..."

  apt update && \
  apt install openjdk-8-jdk unzip apt-transport-https -y

  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
  echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

  echo "[*] Setting up hosts file..."

  echo "127.0.0.1 localhost" > /etc/hosts
  echo "${ELASTICADDRESS} ${ELKHOST}.${ELKDOMAIN} ${ELKHOST}" >> /etc/hosts
}

function GenerateSSLCA {
  echo "[*] Generating SSL CA..."

  rm -rf ${CAWORKINGPATH} && mkdir -p ${CAWORKINGPATH}

  # GENERATING SSL CA AND CERTS
  openssl genrsa -out ${CAWORKINGPATH}ca.key 2048

  openssl req -x509 \
    -new \
    -nodes \
    -subj "/CN=Elastic Certificate Tool Autogenerated CA" \
    -key ${CAWORKINGPATH}ca.key \
    -sha256 \
    -days 1024 \
    -out ${CAWORKINGPATH}ca.crt

  sleep 1
}

function GenerateSSLCerts {
  echo "[*] Generating SSL Certs..."

  GenerateSSLCA

  rm -rf ${CERTWORKINGPATH} && mkdir -p ${CERTWORKINGPATH}

  # PEM FORMAT
  openssl req -new \
    -nodes \
    -newkey rsa:2048 \
    -keyout ${CERTWORKINGPATH}cert.key \
    -out ${CERTWORKINGPATH}cert.req \
    -batch \
    -subj "/CN=${ELKHOST}.${ELKDOMAIN}" \
    -reqexts SAN \
    -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:*.${ELKDOMAIN}"))

  openssl x509 -req \
    -in ${CERTWORKINGPATH}cert.req \
    -CA ${CAWORKINGPATH}ca.crt \
    -CAkey ${CAWORKINGPATH}ca.key \
    -CAcreateserial \
    -out ${CERTWORKINGPATH}cert.crt \
    -days 3650 \
    -sha256 \
    -extfile <(printf "subjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid\nsubjectAltName=DNS:*.${ELKDOMAIN}\nbasicConstraints=CA:FALSE")

  sleep 1
}

function ConfigureElasticsearchSSL {
  mkdir -p "${ELASTICSSLFOLDER}ca"
  mkdir -p "${ELASTICSSLFOLDER}${ELKHOST}.${ELKDOMAIN}"

  cp "${CAWORKINGPATH}ca.crt" "${ELASTICSSLFOLDER}ca/ca.crt"
  cp "${CERTWORKINGPATH}cert.key" "${ELASTICSSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.key"
  cp "${CERTWORKINGPATH}cert.crt" "${ELASTICSSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.crt"

  chmod g+r "${ELASTICSSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.key"

  sleep 0.5
}

function ConfigureElasticsearch {
  ConfigureElasticsearchSSL

  echo "[*] Setting up Elasticsearch config (part 1)..."

  echo "###############################################################################" >> /etc/elasticsearch/elasticsearch.yml
  echo "#          Custom configuration begins below: Do not edit manually.           #" >> /etc/elasticsearch/elasticsearch.yml
  echo "###############################################################################" >> /etc/elasticsearch/elasticsearch.yml

  if [ ${SPLITROLES} -eq 1 ]; then
    echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
  fi

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
  sleep 0.5
}

function ConfigureKibanaSSL {
  mkdir -p "${KIBANASSLFOLDER}ca"
  mkdir -p "${KIBANASSLFOLDER}${ELKHOST}.${ELKDOMAIN}"

  cp "${CAWORKINGPATH}ca.crt" "${KIBANASSLFOLDER}ca/ca.crt"
  cp "${CERTWORKINGPATH}cert.key" "${KIBANASSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.key"
  cp "${CERTWORKINGPATH}cert.crt" "${KIBANASSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.crt"

  chmod g+r "${KIBANASSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.key"

  sleep 0.5
}

function ConfigureKibana {
  ConfigureKibanaSSL

  echo "[*] Setting up Kibana config..."

  
  if [ ${SPLITROLES} -ne 1 ]; then
    KIBANAUSER="kibana_system"
    KIBANAPASS=$(cat ${PASSFILE} | grep -v -i changed | grep -i ${KIBANAUSER} | cut -d' ' -f4)
  else
    KIBANAUSER="${1}"
    KIBANAPASS="${2}"
  fi
  KIBANAKEY=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 32 | head -n 1)

  echo "###############################################################################" >> /etc/kibana/kibana.yml
  echo "#          Custom configuration begins below: Do not edit manually.           #" >> /etc/kibana/kibana.yml
  echo "###############################################################################" >> /etc/kibana/kibana.yml
  echo "server.host: \"0.0.0.0\"" >> /etc/kibana/kibana.yml
  echo "server.name: \"${ELKHOST}\"" >> /etc/kibana/kibana.yml
  echo "server.publicBaseUrl: \"${KIBANABASEURL}\"" >> /etc/kibana/kibana.yml
  echo "elasticsearch.hosts: [ \"https://${ELKHOST}.${ELKDOMAIN}:9200\" ]" >> /etc/kibana/kibana.yml
  echo "elasticsearch.ssl.certificateAuthorities: [ \"${KIBANASSLFOLDER}ca/ca.crt\" ]" >> /etc/kibana/kibana.yml
  echo "elasticsearch.username: \"${KIBANAUSER}\"" >> /etc/kibana/kibana.yml
  echo "elasticsearch.password: \"${KIBANAPASS}\"" >> /etc/kibana/kibana.yml
  echo "xpack.encryptedSavedObjects.encryptionKey: \"${KIBANAKEY}\"" >> /etc/kibana/kibana.yml
  echo "server.ssl.enabled: true" >> /etc/kibana/kibana.yml
  echo "server.ssl.certificate: \"${KIBANASSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.crt\"" >> /etc/kibana/kibana.yml
  echo "server.ssl.key: \"${KIBANASSLFOLDER}${ELKHOST}.${ELKDOMAIN}/${ELKHOST}.${ELKDOMAIN}.key\"" >> /etc/kibana/kibana.yml
  echo "###############################################################################" >> /etc/kibana/kibana.yml

  systemctl restart kibana
  sleep 0.5
}

function ConfigureLogstashSSL {
  mkdir -p "${LOGSTASHSSLFOLDER}ca"

  cp "${CAWORKINGPATH}ca.crt" "${LOGSTASHSSLFOLDER}ca/ca.crt"

  sleep 0.5
}

function ConfigureLogstash {
  ConfigureLogstashSSL

  echo "[*] Setting up Logstash config..."

  if [ ${SPLITROLES} -ne 1 ]; then
    ELASTICUSER="elastic"
    ELASTICPASS=$(cat ${PASSFILE} | grep -v -i changed | grep -i elastic | cut -d' ' -f4)
  else
    ELASTICUSER="${1}"
    ELASTICPASS="${2}"
  fi
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
    sleep 0.5
  fi
}

function InstallElasticsearch {
  echo "[*] Installing Elasticsearch..."

  apt update && apt install elasticsearch -y

  echo "[*] Configuring firewall..."
  ufw allow 9200/tcp
  ufw allow 9300/tcp

  systemctl enable elasticsearch
  sleep 0.5
}

function InstallKibana {
  echo "[*] Installing Kibana..."

  apt update && apt install kibana -y

  echo "[*] Configuring firewall..."
  ufw allow 5601/tcp

  systemctl enable kibana
  sleep 0.5
}

function InstallLogstash {
  echo "[*] Installing Logstash..."

  apt update && apt install logstash -y

  echo "[*] Configuring firewall..."
  ufw allow 5044/tcp

  systemctl enable logstash
  sleep 0.5
}

function CleanUp {
  echo "[*] Cleaning up working path..."

  rm -rf ${CAWORKINGPATH}
  rm -rf ${CERTWORKINGPATH}

  echo "[!] Completed."
}

###########################################################
# Handlers

function ElasticsearchHandler {
  InstallDependency
  GenerateSSLCerts
  InstallElasticsearch
  ConfigureElasticsearch
  CleanUp
}

function KibanaHandler {
  WORKINGSSLPATH=""
  KIBANAUSER=""
  KIBANAPASS=""

  while [[ $# -gt 0 ]]; do
    case ${1} in
      --kibana-user)
        KIBANAUSER="${2}"
        shift
        shift
        ;;
      --kibana-pass)
        KIBANAPASS="${2}"
        shift
        shift
        ;;
      --elasticsearch-ip)
        if [ ! -z $(echo "${2}" | grep -E -o ${VALIDATEIP}) ]; then
          ELASTICADDRESS="${2}"
          shift
          shift
        else
          echo "[!] Invalid IP address provided"
          echo
          ShowHelp
          exit 1
        fi
        ;;
      --ssl-path)
        if [ ! -z $(echo "${2%/}" | grep -E -o ${VALIDATELINUXPATH}) ]; then
          WORKINGSSLPATH="${2%/}"
          shift
          shift
        else
          echo "[!] Invalid path provided"
          echo
          ShowHelp
          exit 1
        fi
        ;;
      *)
        ShowHelp
        exit 1
        ;;
    esac
  done

  if [[ ${SPLITROLES} -eq 1 && (-z ${KIBANAUSER} || -z ${KIBANAPASS}) ]]; then
    echo "[!] Kibana user and password are needed"
    echo
    ShowHelp
    exit 1
  else
    InstallDependency

    if [ -z ${WORKINGSSLPATH} ]; then
      GenerateSSLCerts
    else
      CAWORKINGPATH="${WORKINGSSLPATH}/"
      CERTWORKINGPATH="${WORKINGSSLPATH}/"
    fi

    InstallKibana
    ConfigureKibana ${KIBANAUSER} ${KIBANAPASS}
    CleanUp
  fi
}

function LogstashHandler {
  WORKINGSSLPATH=""
  LOGSTASHUSER=""
  LOGSTASHPASS=""

  while [[ $# -gt 0 ]]; do
    case ${1} in
      --logstash-user)
        LOGSTASHUSER="${2}"
        shift
        shift
        ;;
      --logstash-pass)
        LOGSTASHPASS="${2}"
        shift
        shift
        ;;
      --elasticsearch-ip)
        if [ ! -z $(echo "${2}" | grep -E -o ${VALIDATEIP}) ]; then
          ELASTICADDRESS="${2}"
          shift
          shift
        else
          echo "[!] Invalid IP address provided"
          echo
          ShowHelp
          exit 1
        fi
        ;;
      --ssl-path)
        if [ ! -z $(echo "${2%/}" | grep -E -o ${VALIDATELINUXPATH}) ]; then
          WORKINGSSLPATH="${2%/}"
          shift
          shift
        else
          echo "[!] Invalid path provided"
          echo
          ShowHelp
          exit 1
        fi
        ;;
      *)
        ShowHelp
        exit 1
        ;;
    esac
  done

  if [[ ${SPLITROLES} -eq 1 && (-z ${LOGSTASHUSER} || -z ${LOGSTASHPASS}) ]]; then
    echo "[!] Logstash user and password are needed"
    echo
    ShowHelp
    exit 1
  else
    InstallDependency

    if [ -z ${WORKINGSSLPATH} ]; then
      GenerateSSLCerts
    else
      CAWORKINGPATH="${WORKINGSSLPATH}/"
      CERTWORKINGPATH="${WORKINGSSLPATH}/"
    fi

    InstallLogstash
    ConfigureLogstash ${LOGSTASHUSER} ${LOGSTASHPASS}
    CleanUp
  fi
}

function FullHandler {
  SPLITROLES=0

  InstallDependency
  GenerateSSLCerts
  InstallElasticsearch
  ConfigureElasticsearch
  InstallKibana
  ConfigureKibana
  InstallLogstash
  ConfigureLogstash
  CleanUp
}

###########################################################
# Main

if [[ $# -gt 0 ]]; then
  while [[ $# -gt 0 ]]; do
    key="${1}"
    case ${key} in
      elasticsearch)
        shift
        ElasticsearchHandler
        exit 0
        ;;
      kibana)
        shift
        KibanaHandler $@
        exit 0
        ;;
      logstash)
        shift
        LogstashHandler $@
        exit 0
        ;;
      full)
        shift
        FullHandler
        exit 0
        ;;
      help)
        ShowHelp
        exit 0
        ;;
      *)
        ShowHelp
        exit 1
        ;;
    esac
  done
else
  ShowHelp
fi
