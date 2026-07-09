# Platform Repo — Jenkins on EC2 with Docker

This repository bootstraps the **Platform EC2** only.

It contains Jenkins infrastructure and must not contain the calculator application, PEM files, AWS access keys, or application secrets.

## Included

- Jenkins LTS in Docker
- Docker Compose restart policy
- Persistent Jenkins home
- Host Docker socket access for Docker Pipeline agents
- Multibranch Pipeline and GitHub Pull Request discovery plugins
- SSH Agent plugin for deployment credentials

## Platform EC2 prerequisites

Amazon Linux 2023 with Docker and Docker Compose v2 installed.

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
```

Log out and back in after adding `ec2-user` to the Docker group.

## Start Jenkins

```bash
chmod +x bootstrap.sh verify.sh
./bootstrap.sh
./verify.sh
```

Jenkins will listen on port `8080`.

## AWS access

Attach an EC2 instance role to the Platform EC2. Do not store AWS keys in this repository.

For the lab, the role needs permission to authenticate to and push images into Amazon ECR.

Docker pipeline agents that use the EC2 instance role may require the EC2 metadata response hop limit to be set to `2`.

## SSH deployment key

Store the generated deployment private key in Jenkins Credentials:

- Kind: `SSH Username with private key`
- ID: `application-ec2-ssh`
- Username: `ec2-user`

Do not put the private key in Git or `.env`.

## Repository separation

- `Platform_Repo`: this Jenkins infrastructure only.
- `Application_Repo`: calculator source, tests, application Dockerfile, application Compose file, and Jenkinsfile.
