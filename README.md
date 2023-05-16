# shorten

演示用 SWI-Prolog 开发短链服务。

## 在 Docker 中运行该程序

假设文件`main.pl`中的内容如下

```prolog
:- writeln("Hello, world!").
```

同一个目录下还有一份`Dockerfile`

```dockerfile
FROM swipl
COPY . /app
CMD ["swipl", "-g", "halt.", "-s", "/app/main.pl"]
```

先执行下列命令构建 Docker 镜像

```shell
sudo docker build . -t shorten
```

然后就可以运行该镜像打印经典的 Hello World

```shell
sudo docker run -it shorten
```

## 提供一个 HTTP 协议的接口

有了 HTTP 协议的接口，就可以更方便地为其他人或系统提供服务。SWI-Prolog 的[官方文档](https://www.swi-prolog.org/howto/http/HelloText.html)中介绍了如何开发 HTTP 服务，参照其中的代码，将文件`main.pl`修改为下列内容

```prolog
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).

:- http_handler(root(hello_world), say_hi, []).

server(Port) :-
        http_server(http_dispatch, [port(Port)]).

say_hi(_Request) :-
        format('Content-type: text/plain~n~n'),
        format('Hello World!~n').
```

同时为了让 HTTP 服务启动期间 swipl 进程不要退出，也需要修改`Dockerfile`

```dockerfile
FROM swipl
COPY . /app
CMD ["swipl", "-g", "server(8080)", "/app/main.pl"]
```

启动容器的同时，需要指定将容器内的端口号 8080 映射到宿主机的同一个端口号上来，以便可以在宿主机中请求 HTTP 服务

```shell
sudo docker run -it -p 8080:8080 shorten
```

启动成功后，用`curl`就可以测试该接口了

```shell
curl 'http://localhost:8080/hello_world'
```

将会看到`curl`打印出`Hello World`。
