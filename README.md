# WIC Montana Demonstration Project

## Overview

This is the **project repo** for the WIC Montana Demonstration Project. It describes the overall shape of this project and technical documentation that applies to all parts of the project. In addition, it describes how to run the various components of this project. Technical documentation for each component are contained in their respective repos:

- the **[eligibility screener app repo](https://github.com/navapbc/wic-mt-demo-project-eligibility-screener):** contains all project files related to the eligibility screener Next.js application
- the **[mock API app repo](https://github.com/navapbc/wic-mt-demo-project-mock-api):** contains all project files related to the mock API wrapper for Montana's SPIRIT MIS software

## General Technical Documentation

### Development

[@TODO] For this project, we have dockerized each component and use `docker-compose`.

### Continuous Integration

For CI, we are using [Github Actions](https://github.com/features/actions). In each repo, the primary branch is `main` and we have configured it as a [protected branch](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/managing-a-branch-protection-rule). To merge to `main`, a Pull Request must be made, status checks must pass, and the branch must be up to date.

For our project work, each PR is required to have at least one code review and approval. This is enforced in Github in this project repo, but not in the app repos at the moment, since we are currently at a phase in the project where we are making the same PRs against multiple repos and asking for code reviews of the same code is onerous.

[@TODO] We have enabled the following status checks in each app repo:

- typechecking
- linting
- testing
- security scanning

[@TODO] The eligibility screener repo may also include accessibility scanning.

### Security Scanning

[@TODO] We have enabled Dependabot and CodeQL security and dependency scanning in Github. We have also configured a CI job for Clair.

### Continuous Deployment

[@TODO]

### Infrastructure

We are using [Terraform](https://www.terraform.io) to manage our infrastructure as code.

[@TODO] We are hosting our environments in AWS.
[@TODO] Environments
[@TODO] Secrets
[@TODO] Application environment variables
[@TODO] Logging, Monitoring, and Alerting
