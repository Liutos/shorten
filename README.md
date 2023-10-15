# shorten

演示用 SWI-Prolog 开发短链服务。

## 启动

```shell
docker-compose up
```

启动成功后，就可以请求短链服务的接口了。

```shell
curl -X POST 'http://localhost:8080/api/shorten?url=abcdefg'
```

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

## 修改接口路由

我要实现的短链服务需要提供一个路由为`POST /api/shorten`的接口，这个接口要求参数`url`以表单的方式传入，并返回缩短后的新的 URL。为此，首先需要修改目前这个 HTTP 服务的路由规则。要做到这一点，需要使用由库`library(http/http_dispatch)`所提供的谓词`http_handler`，按照[文档](https://www.swi-prolog.org/pldoc/doc_for?object=http_handler/3)所述：

- 它的第一个参数表示接口路径，用原子类型表达为`/api/shorten`；
- 第二个参数表示处理该接口请求的闭包，此处传入谓词`shorten_url`（定义见后文）；
- 第三个参数是一系列控制选项，为了限制该路径仅接受`POST`方法的请求，此处传入`[methods([post])]`。

在谓词`shorten_url`中，为了从作为入参的请求对象中取出入参`url`，需要用到谓词[`http_parameters`](https://www.swi-prolog.org/pldoc/doc_for?object=http_parameters/2)。它的第一个参数理所当然地是请求对象，第二个参数则是一个由待解析的参数的**规格**组成的列表。符合上述要求的一个写法如下

```prolog
        http_parameters(_Request, [
          url(Url, [string])
        ]),
```

它的意思是从请求对象`_Request`中找出名为`url`的参数，将它的值以字符串类型绑定到变量`Url`上。可以通过在接口的响应结果中回显变量`Url`来验证这一点，完整的谓词`shorten_url`的代码如下

```prolog
shorten_url(Request) :-
        http_parameters(Request, [
          url(Url, [string])
        ]),
        format('Content-type: text/plain~n~n'),
        format('url is ~s', [Url]).
```

用`curl`进行测试的结果如下

```shell
$ curl -F 'url=https://example.com' -X POST 'http://localhost:8080/api/shorten'
url is https://example.com
```

## 将 URL 记录到数据库中

需要一种手段将请求该接口时的参数`url`与短链的关系存储起来，以便在为了可以在遇到对短链的访问时，让访问者被重定向到真正的 URL 上。
