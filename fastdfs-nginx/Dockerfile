## Dockerfile
FROM ubuntu:24.04

ENV FASTDFS_PATH=/opt/fdfs \
  FASTDFS_BASE_PATH=/var/fdfs \
  LIBFASTCOMMON_VERSION="V1.0.43" \
  LIBSERVERFRAME_VERSION="V1.2.3" \
  FASTDFS_NGINX_MODULE_VERSION="V1.22" \
  FASTDFS_VERSION="V6.06" \
  FREENGINX_VERSION="1.25.4" \
  GITHUB_PROXY=https://gh.20230119.xyz/

ENV ADD_STORAGES=

# get all the dependences
RUN apt-get update && apt-get install -y curl git gcc make wget iproute2 libpcre3 libpcre3-dev zlib1g zlib1g-dev openssl libssl-dev tzdata vim iputils-ping telnet \
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

# create the dirs to store the files downloaded from internet
RUN mkdir -p ${FASTDFS_PATH}/libfastcommon \
  && mkdir -p ${FASTDFS_PATH}/fastdfs \
  && mkdir -p ${FASTDFS_PATH}/fastdfs-nginx-module \
  && mkdir ${FASTDFS_BASE_PATH} \
  && mkdir /nginx_conf && mkdir -p /usr/local/nginx/conf/conf.d

WORKDIR ${FASTDFS_PATH}

## compile the libfastcommon
RUN git clone -b $LIBFASTCOMMON_VERSION ${GITHUB_PROXY}https://github.com/happyfish100/libfastcommon.git libfastcommon \
  && cd libfastcommon \
  && ./make.sh \
  && ./make.sh install \
  && rm -rf ${FASTDFS_PATH}/libfastcommon

## compile the libserverframe
#RUN git clone -b $LIBSERVERFRAME_VERSION ${GITHUB_PROXY}https://github.com/happyfish100/libserverframe.git libserverframe \
#  && cd libserverframe \
#  && ./make.sh \
#  && ./make.sh install \
#  && rm -rf ${FASTDFS_PATH}/libserverframe

## compile the fastdfs
RUN git clone -b $FASTDFS_VERSION ${GITHUB_PROXY}https://github.com/happyfish100/fastdfs.git fastdfs \
  && cd fastdfs \
  && ./make.sh \
  && ./make.sh install \
  && cp ${FASTDFS_PATH}/fastdfs/conf/http.conf /etc/fdfs/ \
  && cp ${FASTDFS_PATH}/fastdfs/conf/mime.types /etc/fdfs/ \
  && cp /etc/fdfs/tracker.conf.sample /etc/fdfs/tracker.conf \
  && cp /etc/fdfs/storage.conf.sample /etc/fdfs/storage.conf \
  && cp /etc/fdfs/client.conf.sample /etc/fdfs/client.conf \
  && rm -rf ${FASTDFS_PATH}/fastdfs \
  && sed -i "s|/home/yuqing/fastdfs|/opt/fastdfs/tracker|g" /etc/fdfs/tracker.conf \
  && sed -i "s|/home/yuqing/fastdfs|/opt/fastdfs/storage|g" /etc/fdfs/storage.conf \
  && sed -i "s|/home/yuqing/fastdfs|/opt/fastdfs/storage|g" /etc/fdfs/client.conf

## comile nginx
RUN git clone -b $FASTDFS_NGINX_MODULE_VERSION ${GITHUB_PROXY}https://github.com/happyfish100/fastdfs-nginx-module.git fastdfs-nginx-module \
  && wget https://freenginx.org/download/freenginx-${FREENGINX_VERSION}.tar.gz \
  && tar -zxf freenginx-${FREENGINX_VERSION}.tar.gz \
  && sed -i '33i#pragma GCC diagnostic push\n#pragma GCC diagnostic ignored "-Wformat-truncation"' /opt/fdfs/fastdfs-nginx-module/src/common.c \
  && cd freenginx-${FREENGINX_VERSION} \
  && ./configure --prefix=/usr/local/nginx \
      --add-module=${FASTDFS_PATH}/fastdfs-nginx-module/src/ \
      --with-stream=dynamic \
  && make \
  && make install \
  && ln -s /usr/local/nginx/sbin/nginx /usr/bin/

# 设置nginx和fastdfs联合环境，并配置nginx
RUN cp ${FASTDFS_PATH}/fastdfs-nginx-module/src/mod_fastdfs.conf /etc/fdfs \
    && sed -i "s|^store_path0.*$|store_path0=/opt/fastdfs/storage|g" /etc/fdfs/mod_fastdfs.conf \
    && sed -i "s|^url_have_group_name =.*$|url_have_group_name = true|g" /etc/fdfs/mod_fastdfs.conf

# 默认nginx端口
ENV WEB_PORT 80
# 默认fastdfs端口
ENV FDFS_PORT 22122
ENV HOST_IP 127.0.0.1

# 创建启动脚本
RUN     echo  "\
mkdir -p /opt/fastdfs/storage/data /opt/fastdfs/tracker; \n\
ln -s /opt/fastdfs/storage/data/ /opt/fastdfs/storage/data/M00; \n\n\
sed -i \"s/listen\ .*$/listen\ \$WEB_PORT;/g\" /usr/local/nginx/conf/nginx.conf; \n\
sed -i \"s/reserved_storage_space.*$/reserved_storage_space=5\%/g\" /etc/fdfs/tracker.conf; \n\
sed -i \"s/http.server_port.*$/http.server_port=\$WEB_PORT/g\" /etc/fdfs/storage.conf; \n\n\

if [ \"\$IP\" = \"\" ]; then \n\
    IP=\`ip -4 a show dev eth0 |grep inet | awk '{print \$2}' | awk -F '/' '{print \$1}'\`; \n\
fi \n\

if [ \"\$IP\" = \"\" ]; then \n\
   IP=\$HOST_IP; \n\
fi \n\

sed -i \"s/^tracker_server.*$//g\" /etc/fdfs/client.conf; \n\
echo tracker_server=\$IP:\$FDFS_PORT >>/etc/fdfs/client.conf;  \n\
sed -i \"s/^tracker_server.*$//g\" /etc/fdfs/storage.conf; \n\
echo tracker_server=\$IP:\$FDFS_PORT >>/etc/fdfs/storage.conf;  \n\
sed -i \"s/^tracker_server.*$//g\" /etc/fdfs/mod_fastdfs.conf; \n\
echo tracker_server=\$IP:\$FDFS_PORT >>/etc/fdfs/mod_fastdfs.conf;  \n\n\
/usr/bin/fdfs_trackerd  /etc/fdfs/tracker.conf  ; \n\
/usr/bin/fdfs_storaged /etc/fdfs/storage.conf; \n\
echo -e  \"[group1]\\\ngroup_name=group1\\\nstorage_server_port=23000\\\nstore_path_count=1\\\nstore_path0=/opt/fastdfs/storage\\\n\\\n\" >>/etc/fdfs/mod_fastdfs.conf; \n\

array=(\${ADD_STORAGES//,/ }) \n\
n=23000 \n\
grn=1  \n\
gpstr=group1  \n\
ngxlocstr=group1  \n\
for var in \${array[@]}  \n\
do \n\
  let n=\$n+1 \n\
  let grn=\$grn+1 \n\
  gpstr=\$gpstr/\$var \n\
  ngxlocstr=\$ngxlocstr\|\$var \n\
  mkdir -p /opt/fastdfs/storage_\$var/data; \n\
  ln -s /opt/fastdfs/storage_\$var/data/ /opt/fastdfs/storage_\$var/data/M00; \n\
  cp /etc/fdfs/storage.conf /etc/fdfs/storage_\$var.conf; \n\
  sed -i \"s/^group_name.*$//g\" /etc/fdfs/storage_\$var.conf; \n\
  echo group_name=\$var >>/etc/fdfs/storage_\$var.conf;  \n\
  sed -i \"s/^port.*$//g\" /etc/fdfs/storage_\$var.conf; \n\
  echo port=\$n >>/etc/fdfs/storage_\$var.conf;  \n\
  sed -i \"s/^base_path.*$//g\" /etc/fdfs/storage_\$var.conf; \n\
  echo base_path=/opt/fastdfs/storage_\$var >>/etc/fdfs/storage_\$var.conf;  \n\
  sed -i \"s/^store_path0.*$//g\" /etc/fdfs/storage_\$var.conf; \n\
  echo store_path0=/opt/fastdfs/storage_\$var >>/etc/fdfs/storage_\$var.conf;  \n\
  
  echo -e \"[group\$grn]\\\ngroup_name=\$var\\\nstorage_server_port=\$n\\\nstore_path_count=1\\\nstore_path0=/opt/fastdfs/storage_\$var\\\n\\\n\" >>/etc/fdfs/mod_fastdfs.conf; \n\
  /usr/bin/fdfs_storaged /etc/fdfs/storage_\$var.conf; \n\
done \n\

echo -e \"\\\n\\\ngroup_name=\$gpstr\" >>/etc/fdfs/mod_fastdfs.conf;  \n\

sed -i \"s/^group_count.*$/group_count=\$grn/g\" /etc/fdfs/mod_fastdfs.conf; \n\

echo -e \"\
    events {\\\n\
        worker_connections  1024;\\\n\
    }\\\n\
    http {\\\n\
        include       mime.types;\\\n\
        default_type  application/octet-stream;\\\n\
        server {\\\n\
            listen 80;\\\n\
            server_name localhost;\\\n\
            location ~ ^/(\$ngxlocstr)/M00 {\\\n\
                ngx_fastdfs_module;\\\n\
            }\\\n\
        }\\\n\
    }\">/usr/local/nginx/conf/nginx.conf; \n\

/usr/local/nginx/sbin/nginx; \n\
tail -f /usr/local/nginx/logs/access.log \
">/start.sh \
&& chmod u+x /start.sh

EXPOSE 22122 23000 8080 80

VOLUME ["/opt/fastdfs","/usr/local/nginx"]

WORKDIR /opt/fastdfs

ENTRYPOINT ["/bin/bash","/start.sh"]
