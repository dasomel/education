#!/bin/bash

# 1. 필수 패키지 설치 (Java 1.8+, Maven)
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk maven git

# 2. 환경 변수 설정 (JAVA_HOME)
echo "export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))" >> ~/.bashrc
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))

# 3. egovframe-boot-sample-java-config 소스 클론
git clone https://github.com/eGovFramework/egovframe-boot-sample-java-config.git
cd egovframe-boot-sample-java-config

# 4. 의존성 다운로드 및 Spring Boot 애플리케이션 실행
mvn clean package -DskipTests

# 5. Spring Boot 애플리케이션 실행 (8080 포트, 백그라운드 실행)
nohup mvn spring-boot:run > /dev/null 2>&1 &

echo "egovframe-boot-sample-java-config Spring Boot 애플리케이션이 백그라운드에서 실행 중입니다."
echo "잠시 후 http://localhost:8080/ 에서 서비스가 동작하는지 확인하세요."
