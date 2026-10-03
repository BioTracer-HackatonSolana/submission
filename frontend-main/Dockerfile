FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .

ARG BIOTRACER_MODE=devnet
ARG BIOTRACER_API_URL=https://hackasolana.smartlinksbot.cloud

RUN flutter config --enable-web \
 && flutter pub get \
 && flutter build web --release --no-web-resources-cdn \
      --dart-define=BIOTRACER_MODE=${BIOTRACER_MODE} \
      --dart-define=BIOTRACER_API_URL=${BIOTRACER_API_URL}

FROM nginx:1.27-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html/
EXPOSE 8080
