# Python with Poetry 

This is a barebones example of a Python 3.12.0 project that uses pypi spin up a [Poetry](https://python-poetry.org) managed project that runs a simple [FastAPI](https://fastapi.tiangolo.com) server

### Running this example

```sh
docker build -t stagex-examples/python-poetry -f Containerfile .
docker run --port 8080:80 stagex-example/python-poetry
```
