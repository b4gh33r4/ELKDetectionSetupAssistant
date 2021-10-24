<img src="misc/logo.png" style="float:right" width="500px" alt="ELK Detection Setup Assistant">

ELK Detection Setup Assistant is a `bash` script implemented to support the installation of the ELK stack and to enable Security Detection in a self-managed deployment.

## Use Cases

The script is suitable for `testing` and `evaluation` purposes, it is not designed to perform ELK deployment in production environments.

## Getting Started

To start using the script you have to `clone` this repo . . .

```bash
$ git clone https://github.com/b4gh33r4/ELKDetectionSetupAssistant.git
```
. . . and make the script `executable`.

```bash
$ cd ELKDetectionSetupAssistant/src
$ chmod +x ELKDetectionSetupAssistant.sh
```

Finally, you have to use a `bash` terminal with `root` privileges and run the following command:

```bash
# ./ELKDetectionSetupAssistant.sh
```

## More

The script enables a demo `Logstash` pipeline to parse and ingest contents sent by `Beats` data shippers.

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
