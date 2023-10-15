FROM swipl:stable

COPY . /app/
WORKDIR /app
# 参考[这里](https://learnku.com/articles/26066)的办法，将软件源地址替换为阿里云镜像以便加速。
RUN sed -i s@/deb.debian.org/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
  && apt-get clean \
  && apt-get update \
  && apt-get install -y unixodbc-dev

# 下列代码来自[这里](https://stackoverflow.com/questions/68590463/linux-installing-mysql-odbc-driver-error)，在容器内安装 ODBC 驱动程序。
RUN tar -C /tmp/ -xzvf mysql-connector-odbc-8.0.26-linux-glibc2.12-x86-64bit.tar.gz \
  && cd /tmp/ \
  && cp -r ./mysql-connector-odbc-8.0.26-linux-glibc2.12-x86-64bit/bin/* /usr/local/bin \
  && cp -r ./mysql-connector-odbc-8.0.26-linux-glibc2.12-x86-64bit/lib/* /usr/local/lib \
  && myodbc-installer -a -d -n "MySQL ODBC 8.0 Driver" -t "Driver=/usr/local/lib/libmyodbc8w.so"

# 编译源代码
RUN swipl --goal=main --stand_alone=true -o shorten -c main.pl \
  && cp ./shorten /bin/

EXPOSE 8080

CMD [ "shorten" ]
