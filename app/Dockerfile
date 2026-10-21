# Build stage
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -DskipTests package

# Runtime stage: JRE only, non-root user
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S taskflow && adduser -S -G taskflow -u 10001 taskflow
WORKDIR /app
COPY --from=build --chown=taskflow:taskflow /workspace/target/taskflow-api-1.0.0.jar /app/taskflow.jar
USER 10001:10001
EXPOSE 8080
ENV PORT=8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=70.0", "-XX:+ExitOnOutOfMemoryError", "-jar", "/app/taskflow.jar"]
