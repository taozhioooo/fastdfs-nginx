# fastdfs-nginx
## docker-compose.yaml
storage0不要改
```yaml
networks:
  fastdfs-net:
    driver: bridge
services:
  tracker:
    container_name: tracker
    image: registry.docker.gm/fastdfs-multi-platform:6.12.1-5
    command: tracker
    networks:
      - fastdfs-net
    volumes:   
      - ./fastdfs/tracker:/var/fdfs
      - ./tracker_nginx/conf.d:/usr/local/nginx/conf/conf.d 
    ports:
      - 80:80
  storage0:
    container_name: storage0
    image: registry.docker.gm/fastdfs-multi-platform:6.12.1-5
    command: storage
    networks:
      - fastdfs-net
    environment:
      - TRACKER_SERVER=tracker:22122
    volumes: 
      - ./fastdfs/storage0:/var/fdfs
    depends_on:
      - tracker
```
