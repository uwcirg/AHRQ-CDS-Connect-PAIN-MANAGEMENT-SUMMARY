FROM alpine/git as vcs_checkout

WORKDIR /opt/checkout

RUN git clone https://github.com/cqframework/clinical_quality_language .



FROM openjdk:11 as cql_builder

WORKDIR /opt/app

COPY --from=vcs_checkout /opt/checkout .

WORKDIR Src/java

RUN ./gradlew :cql-to-elm:installDist
