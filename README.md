# hintr

<!-- badges: start -->
[![Project Status: WIP - Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](http://www.repostatus.org/badges/latest/wip.svg)](http://www.repostatus.org/#wip)
[![Travis build status](https://travis-ci.org/mrc-ide/hintr.svg?branch=master)](https://travis-ci.org/mrc-ide/hintr)
[![codecov.io](https://codecov.io/github/mrc-ide/hintr/coverage.svg?branch=master)](https://codecov.io/github/mrc-ide/hintr?branch=master)
<!-- badges: end -->

R API for Naomi app

App to show district level estimates of HIV indicators

## Running in docker

Docker images are built on travis, if on master branch run via:
```
docker run --rm -d --network=host --name hintr_redis redis
docker run --rm -d --network=host --mount type=volume,src=upload_volume,dst=/uploads \
  --name hintr mrcide/hintr:latest
```

Test that container is working by using:
```
curl http://localhost:8888
```

Validate PJNZ:
``` 
curl -X POST -H 'Content-Type: application/json' \
     --data @example/docker_payload.json http://localhost:8888/validate
#> {"status":"success","errors":{},"data":{"filename":"Botswana2018.PJNZ","type":"pjnz","data":{"country":"Botswana"}}}
```

Validate shape file and return serialised data:
``` 
curl -X POST -H 'Content-Type: application/json' \
     --data @example/docker_validate_shape_payload.json http://localhost:8888/validate
```

Validate population data:
```
curl -X POST -H 'Content-Type: application/json' \
     --data @example/docker_validate_population_payload.json http://localhost:8888/validate
#> {"status":"success","errors":{},"data":{"filename":"population.csv","type":"population","data":null}
```

Validate programme ART data:
```
curl -X POST -H 'Content-Type: application/json' \
     --data @example/docker_validate_programme_payload.json http://localhost:8888/validate
```

Validate ANC data:
```
curl -X POST -H 'Content-Type: application/json' \
     --data @example/docker_validate_anc_payload.json http://localhost:8888/validate
```
  
Docker container can be cleaned up using
```
docker rm -f hintr
```

### Input data

Input data should be written to the shared `upload_volume`. When requesting validation pass the absolute path to the file in the request JSON e.g.

```
{
  "type": "pjnz",
  "path": "/uploads/Botswana.pjnz"
}
```

## Validating JSON against schema

To turn on validation of requests and responses you need to set the environmental variable VALIDATE_JSON_SCHEMAS to true. You can do that by writing to a `.Renviron` file, on linux `echo -e "VALIDATE_JSON_SCHEMAS=true" >> .Renviron`.


## Running tests which use redis

To run tests including those which rely on a redis instance being available you need to start a redis docker container
```
docker run --rm -d --network=host --name hintr_redis redis
```
