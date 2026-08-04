# Java (Spring Boot) Dockerfile 템플릿
# TODO: Gradle/Maven 멀티스테이지 빌드 추가
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
