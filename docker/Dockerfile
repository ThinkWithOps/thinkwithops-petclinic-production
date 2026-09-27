# Digest pins resolved from Docker Hub; see docs/validation/v1-containerized.md.
FROM maven:3.9-eclipse-temurin-17@sha256:f1ab639371711ac150c8e344bff7d39d8161c17a531b5dd653d3fa03af554807 AS build
WORKDIR /workspace
COPY pom.xml mvnw ./
COPY .mvn/ .mvn/
RUN chmod +x mvnw
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -ntp dependency:go-offline
COPY src/ src/
COPY LICENSE.txt ./
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -ntp -DskipTests package \
    && cp target/spring-petclinic-*.jar application.jar \
    && java -Djarmode=tools -jar application.jar extract --layers --destination extracted

FROM eclipse-temurin:17-jre-alpine@sha256:a2e1cd0a400a97cf772159f5fff4e05088b4d20097379624cab1874a381ff6f1 AS runtime
ARG SOURCE=https://github.com/ThinkWithOps/thinkwithops-petclinic-production
ARG REVISION=unknown
ARG VERSION=dev
ARG LICENSES=Apache-2.0
LABEL org.opencontainers.image.source=$SOURCE \
      org.opencontainers.image.revision=$REVISION \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.licenses=$LICENSES
RUN addgroup -S -g 10001 petclinic && adduser -S -D -H -u 10001 -G petclinic petclinic
WORKDIR /application
COPY --from=build /workspace/extracted/dependencies/ ./
COPY --from=build /workspace/extracted/spring-boot-loader/ ./
COPY --from=build /workspace/extracted/snapshot-dependencies/ ./
COPY --from=build /workspace/extracted/application/ ./
COPY --from=build /workspace/LICENSE.txt ./LICENSE.txt
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=65.0 -XX:+ExitOnOutOfMemoryError" \
    MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED=true
USER 10001:10001
EXPOSE 8080
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=10s --timeout=5s --start-period=90s --retries=6 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/actuator/health/liveness"]
ENTRYPOINT ["java", "-jar", "application.jar"]
