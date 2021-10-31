<img src="misc/logo.png" style="float:right" width="500px" alt="ELK Detection Setup Assistant">

ELK Detection Setup Assistant is a `bash` script implemented to support the installation of the ELK stack 7.x and to enable Security Detection in a self-managed deployment.

## Use Cases

The script is suitable for `testing` and `evaluation` purposes, it is not designed to perform ELK deployment in production environments.

## Getting Started

To start using the script you have to `clone` this repo . . .

```console
foo@bar:~$ git clone https://github.com/b4gh33r4/ELKDetectionSetupAssistant.git
```

. . . and make the script `executable`.

```console
foo@bar:~$ cd ELKDetectionSetupAssistant/src
foo@bar:~$ chmod +x ELKDetectionSetupAssistant.sh
```

Finally, you have to use a `bash` terminal with `root` privileges (or `sudo`) and choose the appropriate command-line based on the desired installation type:

```console
root@bar:/home/foo# ./ELKDetectionSetupAssistant.sh
  _       _                               __                                               
 |_ | |  | \  _ _|_  _   _ _|_ o  _  ._  (_   _ _|_     ._   /\   _  _ o  _ _|_  _. ._ _|_ 
 |_ | |< |_/ (/_ |_ (/_ (_  |_ | (_) | | __) (/_ |_ |_| |_) /--\ _> _> | _>  |_ (_| | | |_ 
                                                        |                                  

 usage: ./ELKDetectionSetupAssistant.sh OPTION [ARGS]

 OPTIONS:

     elasticsearch          Install and configure Elasticsearch
     kibana                 Install and configure Kibana
     logstash               Install and configure Logstash
     full                   Install and configure ELK
     help                   Show this help

 ARGS:

 usage: ./ELKDetectionSetupAssistant.sh full

 usage: ./ELKDetectionSetupAssistant.sh elasticsearch

 usage: ./ELKDetectionSetupAssistant.sh kibana --kibana-user USERNAME --kibana-pass PASS [--elasticsearch-ip IPADDRESS | --ssl-path PATH]

     --kibana-user          Kibana user
     --kibana-pass          Kibana user password
     --elasticsearch-ip     Elasticsearch node IP address
                            NOTE: default value is 127.0.0.1
     --ssl-path             Path where ssl CA and CERTS are placed
                            NOTE: if omitted the ssl CA and CERTS are newly generated

 usage: ./ELKDetectionSetupAssistant.sh logstash --logstash-user USERNAME --logstash-pass PASS [--elasticsearch-ip IPADDRESS | --ssl-path PATH]

     --logstash-user        Logstash user
     --logstash-pass        Logstash user password
     --elasticsearch-ip     Elasticsearch node IP address
                            NOTE: default value is 127.0.0.1
     --ssl-path             Path where ssl CA and CERTS are placed
                            NOTE: if omitted the ssl CA and CERTS are newly generated
```

As you can see, the setup assistant is able to install `elasticsearch`, `kibana` and `logstash` separately, but it provides the user with a bulk setup mode which installs all the ELK components on a single host.

## More

The script enables an authenticated demo `Logstash` pipeline to parse and ingest contents sent by `Beats` data shippers.

## Requirements

Tested on:

- Ubuntu Server >= 18.04
- 16+ GB RAM
- 100+ GB HDD
- 4+ vCPUs

## License

This project is under the **MIT license**.

## Funding

This is a non-profit project which received neither funding nor sponsorship.
