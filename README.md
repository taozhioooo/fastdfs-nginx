# fastdfs-nginx
## docker-compose.yaml
```yaml
version: '3.8'
services:
  fastdfs:
    container_name: syh-fastdfs
    image: registry.docker.gm/fastdfs-multi-platform:v6.06
    ports:
      - 80:80
      - 22122:22122
    volumes:
      - ./:/opt/fastdfs
    networks:
      - fastdfs-net
networks:
  fastdfs-net:
    driver: bridge
```
