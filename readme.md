# IIS Docker Bootstrap

These commands are used in conjunction with docker to take runtime configuration from a docker environment and build a Web.Config and start IIS.

Both files must be copied into a docker image in the DOCKERFILE, and the entrypoint of the image changed to iisbootstrap.ps1

``` Dockerfile
WORKDIR C:\scripts
COPY scripts\iisbootstrap.ps1 .\
COPY scripts\ReplaceWebConfigToken.ps1 .\
ENTRYPOINT /scripts/iisbootstrap.ps1
```

## Using Tokens

The Web.Config added to the docker image should be tokenized with tokens such as ```@@dbserver@@``` or ```@@svcpassword@@```. Both local environment variables inside the container, and the docker secrets it has access to will be searched, and the tokens replaced with configuration and saved before IIS is started.
**Environment variables and/or secrets with matching names must added when the service is created in Docker as well**

``` bash
docker service create -e dbserver=proddb01 --secret=svcpassword  testiis:latest
```

Optionally, environment variables can be used to point to secrets as well, allowing the use of dockers global secrets as environment-specific

``` bash
docker service create -e svcpassword=secret:devpasswd  --secret=devpassword testiis:latest
```

which will replace @@svcpassword@@ with the contents of the devpassword docker secret
