# CI/CD Platform — Jenkins on EC2 with Docker

This repository contains the infrastructure used to run the Jenkins CI/CD platform for the calculator practical.

It is intentionally separated from the application repository:

- **Platform_Repo** — Jenkins platform and bootstrap files
- **Application_Repo** — calculator source code, tests, Dockerfile, deployment Compose file, and the single Jenkinsfile

---

## Project Objective

The platform provides a production-style delivery path using:

- Jenkins running in Docker on an EC2 instance
- Docker-based Jenkins agents for every pipeline stage
- GitHub webhooks and a Multibranch Pipeline
- Amazon ECR as the container registry
- A dedicated Production EC2 instance for the running application
- SSH deployment with Jenkins credentials
- EC2 instance roles instead of static AWS access keys

```text
Platform_Repo
    ↓ bootstraps
Platform-final EC2
    ↓ runs
Jenkins controller container
    ↓ starts temporary Docker agents
Single Multibranch Pipeline
    ↓ builds and tests Application_Repo
Amazon ECR
    ↓ production pulls the tested image
Production-final EC2
    ↓ runs
calculator-app container
```

---

## Repository Responsibility

This repository owns only the Jenkins platform.

```text
Platform_Repo
├── Dockerfile
├── docker-compose.yml
├── plugins.txt
├── bootstrap.sh
├── verify.sh
├── .env.example
└── README.md
```

It must not contain:

- Calculator source code
- AWS access keys
- Jenkins credentials
- PEM files
- GitHub tokens
- SSH private keys
- Production secrets

---

## Lab Resources

| Resource | Purpose |
|---|---|
| `Platform-final` EC2 | Runs Jenkins and the CI/CD toolchain |
| `Production-final` EC2 | Runs the deployed calculator container |
| `Platform_Repo` | Jenkins infrastructure |
| `Application_Repo` | Application and pipeline definition |
| ECR repository `calculator-app` | Stores versioned application images |
| Jenkins port `8080` | Jenkins web interface |
| Application port `5000` | Calculator service and `/health` endpoint |

The current Production EC2 private address used by the Jenkinsfile is `10.0.4.23`.

---

## How Jenkins Runs

Jenkins is not installed directly on the EC2 operating system.

```text
Platform-final EC2
    ↓
Host Docker Engine
    ↓
platform-jenkins controller container
    ↓
Temporary docker:27-cli pipeline agent
    ↓
Mounted host Docker socket
    ↓
Build, test and push commands
```

The controller mounts:

```text
/var/run/docker.sock
```

This allows the Docker agent to communicate with the Docker Engine on the Platform EC2 host and execute:

```text
docker build
docker run
docker push
```

All pipeline stages run through the Docker agent, as required by the practical.

---

## Docker Compose Design

The Compose configuration provides:

- Jenkins LTS with Java 21
- Persistent Jenkins data in `/var/jenkins_home`
- Host Docker socket access
- Docker group access using the host socket GID
- Port `8080` for the Jenkins UI
- Port `50000` for Jenkins agents
- `restart: unless-stopped` for reboot recovery
- Jenkins HTTP health checking
- Docker log rotation

```text
Jenkins container restarted or recreated
    ↓
/var/jenkins_home remains on the EC2 host
    ↓
Jobs, credentials, plugins and settings remain available
```

---

## Installed Jenkins Plugins

| Plugin | Purpose |
|---|---|
| `workflow-aggregator` | Declarative and scripted Pipeline support |
| `workflow-multibranch` | One pipeline definition across branches and PRs |
| `docker-workflow` | Docker-based pipeline agents |
| `git` | Git checkout support |
| `github-branch-source` | GitHub branch and Pull Request discovery |
| `ssh-agent` | Loads the production SSH deployment key |
| `junit` | Publishes and retains test reports |

---

## Platform EC2 Prerequisites

The host uses Amazon Linux 2023 with:

- Docker Engine
- Docker Compose v2
- Git
- Outbound internet access
- An EC2 instance role that can authenticate to and push images into ECR

Enable Docker:

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
```

Log out and reconnect after adding `ec2-user` to the Docker group.

---

## Bootstrap Jenkins

From the repository root:

```bash
chmod +x bootstrap.sh verify.sh
./bootstrap.sh
./verify.sh
```

`bootstrap.sh` performs:

```text
Verify Docker exists
    ↓
Enable Docker at boot
    ↓
Verify Docker Compose v2
    ↓
Create persistent /var/jenkins_home
    ↓
Read the Docker socket group ID
    ↓
Create the ignored local .env file
    ↓
Validate Compose configuration
    ↓
Build and start platform-jenkins
```

Jenkins becomes available at:

```text
http://<PLATFORM_EC2_PUBLIC_IP>:8080
```

---

## AWS Authentication

AWS keys are not stored in Git or in the Jenkinsfile.

```text
Jenkins Docker agent
    ↓ requests temporary credentials
EC2 Instance Metadata Service
    ↓
Platform EC2 instance role
    ↓
Amazon ECR authentication and image push
```

Because AWS commands run from a container, the EC2 metadata response hop limit is configured as `2`.

The pipeline confirms the active identity with:

```text
aws sts get-caller-identity
```

---

## Jenkins Credentials

Credentials are stored inside Jenkins and injected only when required.

### GitHub API Credential

```text
ID: github-api-token
Type: Username with password
Purpose: Authenticated GitHub API access for branch and PR discovery
```

### Production Deployment Credential

```text
ID: application-ec2-ssh
Type: SSH Username with private key
Username: ec2-user
Purpose: Jenkins SSH access to Production-final
```

The credential ID keeps its original name for Jenkinsfile compatibility, but it connects to `Production-final`.

---

## Production EC2 Requirements

The dedicated production host contains only the runtime tools:

- Docker Engine
- Docker Compose v2
- AWS CLI v2
- `curl`
- `/opt/calculator-app`
- An EC2 role that can pull from ECR
- The Jenkins deployment public key in `~/.ssh/authorized_keys`

It does not build the application and does not need the GitHub repository cloned.

```text
Jenkins sends docker-compose.yml and deployment variables
    ↓
Production-final authenticates to ECR
    ↓
Production-final pulls the selected image
    ↓
Docker Compose recreates calculator-app
```

---

## GitHub Integration

The webhook belongs to `Application_Repo` because application events trigger the pipeline.

```text
Application_Repo push or Pull Request event
    ↓
GitHub webhook
    ↓
Jenkins Multibranch Pipeline
```

`Platform_Repo` is used only to create and operate Jenkins.

---

## Security Choices

- No AWS access keys in Git
- No GitHub token in Git
- No private SSH key in Git
- AWS access uses EC2 instance roles
- Jenkins credentials are injected only while needed
- The application runs on a separate EC2 instance
- The application container runs as a non-root user
- Jenkins data is persisted with restricted host permissions
- Docker logs use size and file-count limits
- Sensitive local `.env` files are ignored

The Docker socket is powerful and is mounted only because the practical requires Jenkins to build and push images with the host Docker Engine.

---

## Verification

Run:

```bash
./verify.sh
```

The script checks:

```text
Docker Compose service status
    ↓
Jenkins container health
    ↓
Docker access from inside Jenkins
    ↓
Required Jenkins plugins
```

Useful manual checks:

```bash
docker compose ps
docker inspect platform-jenkins --format '{{.State.Health.Status}}'
docker exec platform-jenkins docker version
docker exec platform-jenkins jenkins-plugin-cli --list
```

---

## End-to-End Responsibility Map

```text
Developer
    ↓ pushes application code
Application_Repo
    ↓ webhook
Jenkins on Platform-final
    ↓ temporary Docker agent
Build and test application image
    ↓
Amazon ECR
    ↓ SSH deployment instruction
Production-final
    ↓ pulls the image
calculator-app container
    ↓
/health verification
```

The PR-CI and merge-to-master CD logic is documented in the `Application_Repo` README.

---

## Teacher Validation Checklist

- [ ] Jenkins runs through Docker Compose on `Platform-final`
- [ ] Jenkins is reachable on port `8080`
- [ ] Jenkins survives container and host restarts
- [ ] Jenkins can use the host Docker Engine
- [ ] Pipeline, GitHub, SSH and JUnit plugins are installed
- [ ] Platform AWS access uses an EC2 instance role
- [ ] No secrets or private keys exist in the repository
- [ ] `Production-final` can pull images from ECR
- [ ] Jenkins can connect to `Production-final` using its stored SSH credential
- [ ] The Application webhook triggers the single Multibranch Pipeline
