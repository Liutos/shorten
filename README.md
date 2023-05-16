# shorten

演示用 SWI-Prolog 开发短链服务。

## 在 Docker 中运行该程序

假设文件`main.pl`中的内容如下

```prolog
:- writeln("Hello, world!").
```

先执行下列命令构建 Docker 镜像

```shell
sudo docker build . -t shorten
```

然后就可以运行该镜像打印经典的 Hello World

```shell
sudo docker run -it shorten
```
