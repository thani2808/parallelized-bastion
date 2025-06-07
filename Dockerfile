# =========================
# Base Stage - NGINX
# =========================
FROM nginx:alpine as nginx-stage

# Clean and copy static content
RUN rm -rf /usr/share/nginx/html/*
COPY nginx/ /usr/share/nginx/html

# =========================
# Base Stage - Spring Boot
# =========================
FROM openjdk:17-jdk-slim as springboot-stage

LABEL maintainer="thani2808"
WORKDIR /app
COPY springboot/target/*.jar app.jar

# =========================
# Final Stage - Conditional
# =========================
FROM nginx:alpine as nginx-final
COPY --from=nginx-stage /usr/share/nginx/html /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

FROM openjdk:17-jdk-slim as springboot-final
WORKDIR /app
COPY --from=springboot-stage /app/app.jar app.jar
EXPOSE 9002
ENTRYPOINT ["java", "-jar", "app.jar"]
