# IMPORTANT: when an update is needed, run
#
# docker login gitlab-registry.cern.ch
# docker build -t gitlab-registry.cern.ch/rmatev/lb-stack-setup/centos7-build-py3 .
# docker push gitlab-registry.cern.ch/rmatev/lb-stack-setup/centos7-build-py3
# docker logout gitlab-registry.cern.ch

# image should match what is used for lb-docker-run (see build-env)
FROM gitlab-registry.cern.ch/lhcb-core/lbdocker/centos7-build:v4.57

RUN sudo yum install -y python3 \
    && sudo yum clean all && sudo rm -rf /var/cache/yum
