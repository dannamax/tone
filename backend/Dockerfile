# ---- Build stage ----
# mattn/go-sqlite3 依赖 CGO，构建阶段需要 gcc + musl-dev
# 国内无法直连 Docker Hub，默认走 DaoCloud 加速（可用 ARG 覆盖）
# 注意: ARG 必须在首个 FROM 之前声明才是全局, 否则后续阶段不可见
ARG BASE_GOLANG=docker.m.daocloud.io/library/golang:1.25-alpine
ARG BASE_ALPINE=docker.m.daocloud.io/library/alpine:3.21
# 部署时由 CI 注入当前 commit SHA，编译进二进制供 /healthz 暴露
ARG GIT_SHA=unknown
FROM ${BASE_GOLANG} AS builder
# apk 换阿里云源加速
RUN sed -i 's#https\?://dl-cdn.alpinelinux.org#https://mirrors.aliyun.com#g' /etc/apk/repositories \
 && apk add --no-cache gcc musl-dev
# 国内无法直连 proxy.golang.org，使用 goproxy.cn 加速
ENV GOPROXY=https://goproxy.cn,direct
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# 云主机原生 x86_64 构建, 2 核默认并行编译; 内存由 swap 兜底
# 注入版本号（commit SHA）供运行时 /healthz 核对线上版本
RUN CGO_ENABLED=1 go build -trimpath -ldflags="-s -w -X main.Version=${GIT_SHA}" -o /out/seeker ./cmd/server

# ---- Runtime stage ----
FROM ${BASE_ALPINE}
RUN sed -i 's#https\?://dl-cdn.alpinelinux.org#https://mirrors.aliyun.com#g' /etc/apk/repositories \
 && apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=builder /out/seeker /usr/local/bin/seeker
COPY migrations ./migrations
RUN mkdir -p /uploads
EXPOSE 8080
CMD ["/usr/local/bin/seeker"]
