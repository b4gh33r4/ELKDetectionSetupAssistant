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

Finally, you have to use a `bash` terminal with `root` privileges and run the following command:

```console
root@bar:~# ./ELKDetectionSetupAssistant.sh
```

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
