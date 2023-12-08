FROM node:20-alpine as build-frontend
WORKDIR /app
RUN corepack enable

COPY ./frontend /app/
ENV VITE_IS_WEB_UI_MODE=true
RUN yarn install && yarn build


FROM acidrain/python-poetry:3.12-alpine as build-backend
RUN apk add binutils
WORKDIR /app
COPY ./backend /app/
RUN poetry install --no-interaction
RUN poetry run pyinstaller --clean --onefile --name backend main.py


FROM alpine:latest
ENV FASTAPI_ENV=production
ENV OPENAI_API_KEY=
ENV PROXY_URL=""
WORKDIR /app

RUN apk add proxychains-ng

COPY --from=build-frontend /app/dist /app/webui
COPY --from=build-backend /app/dist/backend /app/backend

EXPOSE 8000

CMD if [ -n "$PROXY_URL" ]; then \
        export HOSTNAME="127.0.0.1"; \
        protocol=$(echo $PROXY_URL | cut -d: -f1); \
        host=$(echo $PROXY_URL | cut -d/ -f3 | cut -d: -f1); \
        port=$(echo $PROXY_URL | cut -d: -f3); \
        conf=/etc/proxychains.conf; \
        echo "strict_chain" > $conf; \
        echo "proxy_dns" >> $conf; \
        echo "remote_dns_subnet 224" >> $conf; \
        echo "tcp_read_time_out 15000" >> $conf; \
        echo "tcp_connect_time_out 8000" >> $conf; \
        echo "localnet 127.0.0.0/255.0.0.0" >> $conf; \
        echo "localnet ::1/128" >> $conf; \
        echo "[ProxyList]" >> $conf; \
        echo "$protocol $host $port" >> $conf; \
        cat /etc/proxychains.conf; \
        proxychains -f $conf /app/backend; \
    else \
        /app/backend; \
    fi
